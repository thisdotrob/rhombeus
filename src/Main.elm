import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as JD exposing (Decoder, field, float, string, list, dict)
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
    | Failure String

type Source = Amex | Starling

type alias Model
  = { transactions : (List Transaction)
    , status : Status
    , source : Source
    }

init : () -> (Model, Cmd Msg)
init _ =
  ({ status = Loading , transactions = [], source = Amex }
  , getTransactions Amex)

type Msg
  = GetTransactions
  | GotTransactions (Result Http.Error (List Transaction))
  | UpdateTags String String
  | PostTags
  | SwitchSource Source

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GetTransactions ->
      ({ model | status = Loading }, getTransactions model.source)

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

    UpdateTags ref newTags ->
        ({ model
             | transactions = List.map (maybeUpdateTags ref newTags) model.transactions
         }
        , Cmd.none
        )

    PostTags ->
        ({ model | status = Loading }
        , postTags model.source (List.filter (\t -> t.tagsUpdated) model.transactions))

    SwitchSource newSource ->
        ({ model | source = newSource }, getTransactions newSource)

getErrMsg : Http.Error -> String
getErrMsg err =
    case err of
        Http.BadUrl msg -> msg
        Http.Timeout -> "Timeout"
        Http.NetworkError -> "Network error"
        Http.BadStatus status -> "Bad status: " ++ (String.fromInt status)
        Http.BadBody msg -> msg

maybeUpdateTags : String -> String -> Transaction -> Transaction
maybeUpdateTags id newTags transaction =
    if transaction.id  == id then
        { transaction | tags = newTags, tagsUpdated = True }
    else
        transaction

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
    h2 [] [ text (case model.source of
                      Amex -> "Amex"
                      Starling -> "Starling")
          ]

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
      div [] [ button [ onClick PostTags ] [ text "Save" ]
             , button [ onClick (SwitchSource (case model.source of
                                                  Amex -> Starling
                                                  Starling -> Amex))] [ text "Switch source" ]
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
    tr [] [ td [] [ text transaction.date ]
          , td [] [ text (String.fromFloat transaction.amount) ]
          , td [] [ text transaction.description ]
          , td [] [ input
                        [ placeholder "Enter some tags..."
                        , value transaction.tags
                        , onInput (UpdateTags transaction.id)
                        ]
                        []
                  ]
          ]

getTransactions : Source -> Cmd Msg
getTransactions source =
  Http.get
    { url = case source of
                Starling -> "http://localhost:4567/starling/transactions"
                Amex -> "http://localhost:4567/amex/transactions"
    , expect = Http.expectJson GotTransactions transactionListDecoder
    }

type alias Transaction =
  { tagsUpdated : Bool
  , id : String
  , date : String
  , amount : Float
  , description : String
  , tags : String
  }

transactionDecoder : Decoder Transaction
transactionDecoder =
  JD.map5 (Transaction False)
      (field "id" string)
      (field "date" string)
      (field "amount" float)
      (field "description" string)
      (field "tags" string)

transactionListDecoder : Decoder (List Transaction)
transactionListDecoder =
  JD.list transactionDecoder

transactionEncoder : Transaction -> List (String, JE.Value)
transactionEncoder t =
  [("id", JE.string t.id), ("tags", JE.string t.tags)]

postTags : Source -> List Transaction -> Cmd Msg
postTags source transactions =
    Http.post
        { url = case source of
                    Starling -> "http://localhost:4567/starling/update_tags"
                    Amex -> "http://localhost:4567/amex/update_tags"
        , expect = Http.expectJson GotTransactions transactionListDecoder
        , body = Http.jsonBody (JE.list JE.object (List.map transactionEncoder transactions)) }
