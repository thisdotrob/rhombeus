import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as JD exposing (Decoder, field, string, list, dict)



-- MAIN


main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }



-- MODEL


type Model
  = Failure
  | Loading
  | Success (List Transaction)


init : () -> (Model, Cmd Msg)
init _ =
  (Loading, getTransactions)



-- UPDATE


type Msg
  = GetTransactions
  | GotTransactions (Result Http.Error (List Transaction))


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GetTransactions ->
      (Loading, getTransactions)

    GotTransactions result ->
      case result of
        Ok transactionList ->
          (Success transactionList, Cmd.none)

        Err _ ->
          (Failure, Cmd.none)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none



-- VIEW


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
  case model of
    Failure ->
      div []
        [ text "I could not load transactions for some reason. "
        , button [ onClick GetTransactions ] [ text "Try Again!" ]
        ]

    Loading ->
      text "Loading..."

    Success transactionList ->
      div []
        [ button [ onClick GetTransactions, style "display" "block" ] [ text "Refresh" ]
        , viewTransactionList transactionList
        ]

viewTransactionList : (List Transaction) -> Html Msg
viewTransactionList transactionList =
  table []
    [ thead [] [ text "Ref", text "Date", text "Amount", text "Counter Party" ]
    , tbody [] (List.map viewTransaction transactionList)
    ]

viewTransaction : Transaction -> Html Msg
viewTransaction transaction =
    tr [] [ td [] [ text transaction.reference ]
          , td [] [ text transaction.transactionDate ]
          , td [] [ text transaction.minorUnits ]
          , td [] [ text transaction.counterPartyName ]
          ]



-- HTTP


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
  }

transactionDecoder : Decoder Transaction
transactionDecoder =
  JD.map6 Transaction
      (field "reference" string)
      (field "transaction_date" string)
      (field "process_date" string)
      (field "minor_units" string)
      (field "counter_party_name" string)
      (field "description" string)

transactionListDecoder : Decoder (List Transaction)
transactionListDecoder =
  JD.list transactionDecoder
