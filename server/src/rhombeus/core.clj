(ns rhombeus.core
  (:require [io.pedestal.http :as http]
            [io.pedestal.http.body-params :as params]
            [io.pedestal.http.route :as route]
            [io.pedestal.http.ring-middlewares :as middlewares]
            [ring.middleware.session.memory :as memory]
            [hiccup.page :as hiccup]
            [rhombeus.auth :as auth])
  (:gen-class))

(def index-page
  {:name :index-page
   :enter
   (fn [context]
     (let [page (hiccup/html5
                 [:head
                  [:title "Update tags"]
                  [:link {:href "styles.css" :rel "stylesheet"}]
                  [:script {:src "main.js"}]]
                 [:body
                  [:div {:id "elm"}]
                  [:script {:src "init.js"}]])]
       (assoc context :response {:headers {"Content-Type" "text/html"}
                                 :status 200
                                 :body page})))})

(def tags-page
  {:name :tags-page
   :enter
   (fn [context]
     (let [page (hiccup/html5
                 [:head
                  [:title "Tags"]
                  [:link {:href "styles.css" :rel "stylesheet"}]
                  [:script {:src "tags.js"}]]
                 [:body
                  [:div {:id "elm"}]
                  [:script {:src "init.js"}]])]
       (assoc context :response {:headers {"Content-Type" "text/html"}
                                 :status 200
                                 :body page})))})

(def filter-page
  {:name :filter-page
   :enter
   (fn [context]
     (let [page (hiccup/html5
                 [:head
                  [:title "Filter"]
                  [:link {:href "styles.css" :rel "stylesheet"}]
                  [:script {:src "filter.js"}]]
                 [:body
                  [:div {:id "elm"}]
                  [:script {:src "init.js"}]])]
       (assoc context :response {:headers {"Content-Type" "text/html"}
                                 :status 200
                                 :body page})))})

(def body-parser (params/body-params))
(def session-interceptor (middlewares/session (merge {:store (memory/memory-store)}
                                                     (when (= "Y" (System/getenv "RHOMBEUS_HTTPS_ENABLED"))
                                                       {:cookie-attrs {:secure true}}))))

(def routes
  (route/expand-routes
   #{["/" :get [session-interceptor auth/login auth/authenticate index-page]]
     ["/tags" :get [session-interceptor auth/login auth/authenticate tags-page]]
     ["/filter" :get [session-interceptor auth/login auth/authenticate filter-page]]

     ;;["/all/transactions" :get [session-interceptor authenticate all-transactions]]
     ;;["/amex/transactions" :get [session-interceptor authenticate amex-transactions]]
     ;;["/starling/transactions" :get [session-interceptor authenticate starling-transactions]]
     ;;["/all/tags" :get [session-interceptor authenticate all-tags]]
     ;;["/tags" :post [body-parser session-interceptor authenticate insert-tags]]
     ;;["/delete_tag" :post [body-parser session-interceptor authenticate delete-tag]]
     ;;["/amex/update_tags" :post [body-parser session-interceptor authenticate amex-update-tags]]
     ;;["/starling/update_tags" :post [body-parser session-interceptor authenticate starling-update-tags]]

     }))

(def service-map
  {::http/routes routes
   ::http/type   :jetty
   ::http/port   8891
   ::http/secure-headers {:content-security-policy-settings "object-src 'none'; script-src 'self' 'unsafe-eval' 'unsafe-inline'"}
   ::http/resource-path "/public"})

(defn -main []
  (http/start (http/create-server service-map)))
