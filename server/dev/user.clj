(ns user
  (:require [io.pedestal.http :as http]
            [clojure.tools.namespace.repl :as tools]
            [rhombeus.core :as rhombeus]))

(defonce server (atom nil))

(defn start-dev []
  (reset! server
          (http/start (http/create-server
                       (assoc rhombeus/service-map
                              ::http/join? false))))
  nil)

(defn stop-dev []
  (http/stop @server)
  (reset! server nil)
  nil)

(defn refresh [] (tools/refresh))
