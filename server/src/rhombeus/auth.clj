(ns rhombeus.auth
  (:require [clojure.data.json :as json]
            [io.pedestal.interceptor.chain :as chain]
            [clj-http.client :as http-client]
            [java-time :as t])
  (:import org.apache.commons.codec.binary.Base64
           java.security.KeyFactory
           java.security.spec.RSAPublicKeySpec
           java.security.Signature
           java.security.Security
           (org.bouncycastle.util BigIntegers))
  (:gen-class))

(def REDIRECT-URI (System/getenv "RHOMBEUS_REDIRECT_URI"))

(when (nil? (Security/getProvider "BC"))
  (Security/addProvider (org.bouncycastle.jce.provider.BouncyCastleProvider.)))

(defn read-json [s]
  (json/read-str s :key-fn keyword))

(defn base64->bytes [s]
  (Base64/decodeBase64 (.getBytes s "UTF-8")))

(defn base64->str [val]
  (String. (base64->bytes val)))

(defn base64->biginteger [val]
  (let [bs (base64->bytes val)]
    (BigIntegers/fromUnsignedByteArray bs)))

(defn str->base64 [s]
  (Base64/encodeBase64URLSafeString (.getBytes s)))

(defn jwt->payload [jwt]
  (-> (re-find #".+\.(.+)\." jwt)
      (get 1)
      base64->str
      read-json))

(def token-auth-header
  (str "Basic "
       (str->base64 (str (System/getenv "RHOMBEUS_COGNITO_CLIENT_ID")
                      ":"
                      (System/getenv "RHOMBEUS_COGNITO_CLIENT_SECRET")))))

(defn jwk->public-key [{:keys [n e] :as jwk}]
  (let [kf (KeyFactory/getInstance "RSA")
        n (base64->biginteger n)
        e (base64->biginteger e)]
    (.generatePublic kf (RSAPublicKeySpec. n e))))

(defn get-public-key! [jwt]
  (let [kid (-> jwt
                (clojure.string/split #"\.")
                first
                base64->str
                read-json
                :kid)
        url (str "https://cognito-idp.us-east-1.amazonaws.com/"
                 (System/getenv "RHOMBEUS_COGNITO_USER_POOL_ID")
                 "/.well-known/jwks.json")
        {:keys [body status]} (http-client/get url {:throw-exceptions false})]
    (if (= status 200)
      (let [jwks (->> body
                      read-json
                      :keys
                      (map #(vector (:kid %) %))
                      (into {}))
            jwk (get jwks kid)]
        (if jwk
          (jwk->public-key jwk)
          (println "No matching jwk found" kid)))
      (println "Non-200 from public key endpoint" status))))

(defn signature-verified? [public-key jwt]
  (let [[_ input signature] (->> jwt
                                 (re-find #"(.+\..+)\.(.+)")
                                 (map #(.getBytes % "UTF-8")))]
    (-> (doto (Signature/getInstance "SHA256withRSA" "BC")
          (.initVerify public-key)
          (.update input))
        (.verify (Base64/decodeBase64 signature)))))

(defn correct-claims? [jwt]
  (= [(System/getenv "RHOMBEUS_COGNITO_CLIENT_ID")
      (str "https://cognito-idp.us-east-1.amazonaws.com/"
           (System/getenv "RHOMBEUS_COGNITO_USER_POOL_ID"))
      "id"]
     (-> (jwt->payload jwt)
         ((juxt :aud :iss :token_use)))))

(defn get-tokens! [code]
  (let [params {:grant_type "authorization_code"
                :code code
                :client_id (System/getenv "RHOMBEUS_COGNITO_CLIENT_ID")
                :redirect_uri REDIRECT-URI}
        {:keys [status body]} (http-client/post "https://auth.spacetrumpet.co.uk/oauth2/token"
                                                {:headers {"Authorization" token-auth-header}
                                                 :throw-exceptions false
                                                 :form-params params})
        {:keys [id_token refresh_token expires_in]} (read-json body)]
    (if (= status 200)
      (if-let [public-key (get-public-key! id_token)]
        (if (correct-claims? id_token)
          (if (signature-verified? public-key id_token)
            {:id-token id_token
             :refresh-token refresh_token
             :expiry (t/plus (t/instant) (t/seconds expires_in))}
            (println "Signature not verified"))
          (println "Incorrect claims"))
        (println "No matching public-key found"))
      (println "Non-200 from token endpoint" status))))

(defn refresh-tokens! [refresh-token]
  (let [params {:grant_type "refresh_token"
                :refresh_token refresh-token
                :client_id (System/getenv "RHOMBEUS_COGNITO_CLIENT_ID")}
        {:keys [status body]} (http-client/post "https://auth.spacetrumpet.co.uk/oauth2/token"
                                                {:headers {"Authorization" token-auth-header}
                                                 :throw-exceptions false
                                                 :form-params params})
        {:keys [id_token expires_in]} (json/read-str body :key-fn keyword)]
    (if (= status 200)
      (if-let [public-key (get-public-key! id_token)]
        (if (correct-claims? id_token)
          (if (signature-verified? public-key id_token)
            {:id-token id_token
             :refresh-token refresh-token
             :expiry (t/plus (t/instant) (t/seconds expires_in))}
            (println "Signature not verified"))
          (println "Incorrect claims"))
        (println "No matching public-key found"))
      (println "Non-200 from token endpoint" status))))

(def redirect-to-login-response
  {:status 302
   :headers {"Location" (str "https://auth.spacetrumpet.co.uk/login?client_id="
                             (System/getenv "RHOMBEUS_COGNITO_CLIENT_ID")
                             "&response_type=code"
                             "&scope=aws.cognito.signin.user.admin+email+openid+phone+profile"
                             "&redirect_uri="
                             REDIRECT-URI)}})

(defn successful-login-response [tokens]
  {:status 302
   :session {:tokens tokens}
   :headers {"Location" REDIRECT-URI}})

(def login
  {:name :login
   :enter
   (fn [{{{:keys [tokens]} :session
         {:keys [code]} :query-params}
        :request :as context}]
     (if tokens
       context
       (if-let [tokens (and code (get-tokens! code))]
         (assoc context :response (successful-login-response tokens))
         (assoc context :response redirect-to-login-response))))})

(def authenticate
  {:name :authenticate
   :enter
   (fn [context]
     (let [{:keys [id-token refresh-token expiry]} (get-in context [:request :session :tokens])
           payload (and id-token
                        (jwt->payload id-token))]
       (cond
         (not (:sub payload))
         (-> (assoc context :response {:status 401 :body "No sub"})
             chain/terminate)

         (not (t/before? (t/instant) expiry))
         (if-let [{:keys [id-token] :as tokens} (refresh-tokens! refresh-token)]
           (let [payload (jwt->payload id-token)]
             (if (= (System/getenv "RHOMBEUS_USER_SUB") (:sub payload))
               (assoc-in context [:request :session :tokens] tokens)
               (-> (assoc context :response {:status 401 :body "Invalid user"})
                   chain/terminate)))
           (-> (assoc context :response {:status 401 :body "Couldn't refresh tokens"})
               chain/terminate))

         :else
         (if (= (System/getenv "RHOMBEUS_USER_SUB") (:sub payload))
           context
           (-> (assoc context :response {:status 401 :body "Invalid user"})
               chain/terminate)))))
   :leave
   (fn [{{session :session} :request :as context}]
     (assoc-in context [:response :session] session))})
