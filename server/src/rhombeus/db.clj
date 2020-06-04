(ns rhombeus.db
  (:require [next.jdbc.sql :as sql]
            [next.jdbc :as jdbc]
            [next.jdbc.result-set :as result-set])
  (:gen-class))

(extend-protocol result-set/ReadableColumn
  java.sql.Date
  (read-column-by-label ^java.time.LocalDate [^java.sql.Date v _]
    (keyword (.toString v)))
  (read-column-by-index ^java.time.LocalDate [^java.sql.Date v _2 _3]
    (keyword (.toString v))))

(def db {:dbtype "postgres" :dbname (System/getenv "RHOMBEUS_PG_DBNAME")
         :host (System/getenv "RHOMBEUS_PG_HOST")
         :user (System/getenv "RHOMBEUS_PG_USER")
         :password (System/getenv "RHOMBEUS_PG_PASSWORD")})

(def ds (jdbc/get-datasource db))

(defn as-unqualified-kebab-maps [rs opts]
  (let [kebab #(clojure.string/replace % #"_" "-")]
    (result-set/as-unqualified-modified-maps rs (assoc opts :label-fn kebab))))
