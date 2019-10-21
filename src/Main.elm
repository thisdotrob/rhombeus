import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as JD exposing (Decoder, field, string, list, dict)
import Json.Encode as JE

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
  ({ status = Loading , transactions = [] }
  , getTransactions)

type Msg
  = GetTransactions
  | GotTransactions (Result Http.Error (List Transaction))
  | UpdateTags String String
  | PostTags

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GetTransactions ->
      ({ model | status = Loading }, getTransactions)

    GotTransactions result ->
      case result of
        Ok transactionList ->
          ({ model | status = Success, transactions = transactionList }
          , Cmd.none
          )

        Err _ ->
          ({ model | status = Failure }, Cmd.none)

    UpdateTags ref newTags ->
        ({ model
             | transactions = List.map (maybeUpdateTags ref newTags) model.transactions
         }
        , Cmd.none
        )

    PostTags ->
        ({ model | status = Loading }
        , postTags (List.filter (\t -> t.tagsUpdated) model.transactions))

maybeUpdateTags : String -> String -> Transaction -> Transaction
maybeUpdateTags ref newTags transaction =
    if transaction.reference  == ref then
        { transaction | tags = newTags, tagsUpdated = True }
    else
        transaction

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
      div [] [ button [ onClick PostTags ] [ text "Save" ]
             , div [ class "verticalDivider"] []
             , viewTransactionList model.transactions
             ]

viewTransactionList : (List Transaction) -> Html Msg
viewTransactionList transactionList =
  table []
    [ thead []
          [ tr [] [ td [] [ text "Date" ]
                  , td [] [ text "Amount" ]
                  , td [] [ text "Description" ]
                  , td [] [ text "Tags" ]
                  ]
          ]
    , tbody [] (List.map viewTransaction transactionList)
    ]

viewTransaction : Transaction -> Html Msg
viewTransaction transaction =
    tr [] [ td [] [ text transaction.transactionDate ]
          , td [] [ text transaction.minorUnits ]
          , td [] [ text transaction.counterPartyName ]
          , td [] [ input
                        [ placeholder "Enter some tags..."
                        , value transaction.tags
                        , onInput (UpdateTags transaction.reference)
                        ]
                        []
                  ]
          ]

getTransactions : Cmd Msg
getTransactions =
  Http.get
    { url = "http://localhost:4567/amex"
    , expect = Http.expectJson GotTransactions transactionListDecoder
    }

type alias Transaction =
  { tagsUpdated : Bool
  , reference : String
  , transactionDate : String
  , processDate : String
  , minorUnits : String
  , counterPartyName : String
  , description : String
  , tags : String
  }

transactionDecoder : Decoder Transaction
transactionDecoder =
  JD.map7 (Transaction False)
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

transactionEncoder : Transaction -> List (String, JE.Value)
transactionEncoder t =
  [("reference", JE.string t.reference), ("tags", JE.string t.tags)]

postTags : List Transaction -> Cmd Msg
postTags transactions =
    Http.post
        { url = "http://localhost:4567/update_tags"
        , expect = Http.expectJson GotTransactions transactionListDecoder
        , body = Http.jsonBody (JE.list JE.object (List.map transactionEncoder transactions)) }
