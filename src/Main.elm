import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as JD exposing (Decoder, field, string, list, dict)

main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

type Status = Loading
    | Success
    | Failure

type alias Model
  = { transactions : (List Transaction)
    , status : Status
    }

init : () -> (Model, Cmd Msg)
init _ =
  ({ status = Loading, transactions = [] }, getTransactions)

type Msg
  = GetTransactions
  | GotTransactions (Result Http.Error (List Transaction))

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GetTransactions ->
      ({ model | status = Loading}, getTransactions)

    GotTransactions result ->
      case result of
        Ok transactionList ->
          ({ model | status = Success, transactions = transactionList }
          , Cmd.none
          )

        Err _ ->
          ({ model | status = Failure }, Cmd.none)

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

view : Model -> Html Msg
view model =
  div []
    [ viewHeader
    , viewBody model
    ]

viewHeader : Html Msg
viewHeader =
  h2 [] [ text "Transactions" ]

viewBody : Model -> Html Msg
viewBody model =
  case model.status of
    Failure ->
      div []
        [ text "I could not load transactions for some reason. "
        , button [ onClick GetTransactions ] [ text "Try Again!" ]
        ]

    Loading ->
      text "Loading..."

    Success ->
      div []
        [ button [ onClick GetTransactions, style "display" "block" ] [ text "Refresh" ]
        , viewTransactionList model.transactions
        ]

viewTransactionList : (List Transaction) -> Html Msg
viewTransactionList transactionList =
  table []
    [ thead []
          [ tr [] [ td [] [ text "Reference" ]
                  , td [] [ text "Date" ]
                  , td [] [ text "Amount" ]
                  , td [] [ text "Description" ]
                  , td [] [ text "Tags" ]
                  ]
          ]
    , tbody [] (List.map viewTransaction transactionList)
    ]

viewTransaction : Transaction -> Html Msg
viewTransaction transaction =
    tr [] [ td [] [ text transaction.reference ]
          , td [] [ text transaction.transactionDate ]
          , td [] [ text transaction.minorUnits ]
          , td [] [ text transaction.counterPartyName ]
          , td [] [ text transaction.tags ]
          ]

getTransactions : Cmd Msg
getTransactions =
  Http.get
    { url = "http://localhost:4567/amex"
    , expect = Http.expectJson GotTransactions transactionListDecoder
    }

type alias Transaction =
  { reference : String
  , transactionDate : String
  , processDate : String
  , minorUnits : String
  , counterPartyName : String
  , description : String
  , tags : String
  }

transactionDecoder : Decoder Transaction
transactionDecoder =
  JD.map7 Transaction
      (field "reference" string)
      (field "transaction_date" string)
      (field "process_date" string)
      (field "minor_units" string)
      (field "counter_party_name" string)
      (field "description" string)
      (field "tags" string)

transactionListDecoder : Decoder (List Transaction)
transactionListDecoder =
  JD.list transactionDecoder
