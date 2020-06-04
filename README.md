# RHOMBEUS

An Elm/Clojure program to manage tags for financial transactions in Postgres

## Requirements

Clojure (v1.10.1) Postgres (v11.5) Elm (v0.19)

## Development
### Starting
Change into the `client` directory and compile the Elm source with:
```
make Main.elm Tags.elm Filter.elm
```

Change into the `server` directory and Start the server compiler, repl and service:
```
clojure -A:dev -m rebel-readline.main
(start-dev)
```

Navigate to `http://localhost:8891`.

### Restarting
From the Clojure repl:
```
(stop-dev)
(refresh)
(start-dev)
```

## Prod build

Change into the `client` directory and compile the Elm source with:
```
make Main.elm Tags.elm Filter.elm
```

Change into the `server` directory and create the uberjar:
```
./uberdeps/package.sh
```

This will create `target/rhombeus.jar`.

To run it:
```
java -cp target/rhombeus.jar clojure.main -m rhombeus.core
```
