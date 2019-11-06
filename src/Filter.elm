import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as JD exposing (Decoder, field, float, string, list, dict)

main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

type Status = Loading
    | Success
    | Failure String

type alias Model
  = { transactions : (List Transaction)
    , status : Status
    , tags : String
    }

init : () -> (Model, Cmd Msg)
init _ =
  ({ status = Loading , transactions = [], tags = "" }
  , getTransactions ""
  )

type Msg
  = GetTransactions
  | GotTransactions (Result Http.Error (List Transaction))
  | UpdateSearchTerm String

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GetTransactions ->
      ({ model | status = Loading }, getTransactions model.tags)

    GotTransactions result ->
      case result of
        Ok transactionList ->
          ({ model | status = Success, transactions = transactionList }
          , Cmd.none
          )

        Err e ->
            let errMsg = (getErrMsg e)
            in
            ({ model | status = Failure errMsg }, Cmd.none)

    UpdateSearchTerm newTags ->
        ({ model | tags = newTags }, getTransactions newTags)

getErrMsg : Http.Error -> String
getErrMsg err =
    case err of
        Http.BadUrl msg -> msg
        Http.Timeout -> "Timeout"
        Http.NetworkError -> "Network error"
        Http.BadStatus status -> "Bad status: " ++ (String.fromInt status)
        Http.BadBody msg -> msg

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

view : Model -> Html Msg
view model =
  div []
    [ viewHeader model
    , viewBody model
    ]

viewHeader : Model -> Html Msg
viewHeader model =
    h2 [] [ text "Search by tag" ]

viewBody : Model -> Html Msg
viewBody model =
  case model.status of
    Failure errMsg ->
      div []
        [ div [] [ text "I could not load transactions for some reason.\n" ]
        , div [] [ text errMsg ]
        , button [ onClick GetTransactions ] [ text "Try Again!" ]
        ]

    Loading ->
      text "Loading..."

    Success ->
        div [] [ input [ placeholder "Filter by tags", value model.tags, onInput UpdateSearchTerm ] []
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
                  , td [] [ text "Source" ]
                  ]
          ]
    , tbody [] (List.map viewTransaction transactionList)
    ]

viewTransaction : Transaction -> Html Msg
viewTransaction transaction =
    tr [] [ td [] [ text transaction.date ]
          , td [] [ text (String.fromFloat transaction.amount) ]
          , td [] [ text transaction.description ]
          , td [] [ text transaction.tags ]
          , td [] [ text transaction.source ]
          ]

getTransactions : String -> Cmd Msg
getTransactions tags =
  Http.get
    { url = String.append "http://localhost:4567/all/transactions?tags=" tags
    , expect = Http.expectJson GotTransactions transactionListDecoder
    }

type alias Transaction =
  { id : String
  , date : String
  , amount : Float
  , description : String
  , tags : String
  , source : String
  }

transactionDecoder : Decoder Transaction
transactionDecoder =
  JD.map6 Transaction
      (field "id" string)
      (field "date" string)
      (field "amount" float)
      (field "description" string)
      (field "tags" string)
      (field "source" string)

transactionListDecoder : Decoder (List Transaction)
transactionListDecoder =
  JD.list transactionDecoder
