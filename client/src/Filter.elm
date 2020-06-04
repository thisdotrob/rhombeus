import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Time
import Array
import Json.Decode as JD exposing (Decoder, field, float, int, string, list, dict)

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
    , total : Float
    , avgPerMonth : Float
    , monthsDiff : Float
    , dateFrom : String
    , dateTo : String
    }

init : () -> (Model, Cmd Msg)
init _ =
    let model = { status = Loading
                , transactions = []
                , tags = ""
                , total = 0.0
                , avgPerMonth = 0.0
                , monthsDiff = 0.0
                , dateFrom = ""
                , dateTo = ""
                }
    in
        (model, getTransactions model)

type Msg
  = GetTransactions
  | GotTransactions (Result Http.Error (List Transaction))
  | UpdateSearchTerm String
  | UpdateDateFrom String
  | UpdateDateTo String

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GetTransactions ->
      ({ model | status = Loading }, getTransactions model)

    GotTransactions result ->
      case result of
        Ok transactionList ->
          ({ model | status = Success, transactions = transactionList, total = calcTotal transactionList, avgPerMonth = calcAvgPerMonth transactionList, monthsDiff = calcMonthsDiff transactionList }
          , Cmd.none
          )

        Err e ->
            let errMsg = (getErrMsg e)
            in
            ({ model | status = Failure errMsg }, Cmd.none)

    UpdateSearchTerm newTags ->
        let newModel = { model | tags = newTags }
        in
        (newModel, getTransactions newModel)

    UpdateDateFrom newDate ->
        let newModel = { model | dateFrom = newDate }
        in
        (newModel, getTransactions newModel)

    UpdateDateTo newDate ->
        let newModel = { model | dateTo = newDate }
        in
        (newModel, getTransactions newModel)

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
               , div [ class "verticalDivider" ] []
               , input [ placeholder "Date from", value model.dateFrom, onInput UpdateDateFrom ] []
               , div [ class "verticalDivider" ] []
               , input [ placeholder "Date to", value model.dateTo, onInput UpdateDateTo ] []
               , viewTransactionList model.transactions
               , viewSummaryStats model.total model.avgPerMonth model.monthsDiff
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
  let
    posix = (Time.millisToPosix transaction.date)
    year = String.fromInt (Time.toYear Time.utc posix)
    month = (toMonthStr (Time.toMonth Time.utc posix))
    day = String.fromInt (Time.toDay Time.utc posix)
    hour   = String.fromInt (Time.toHour   Time.utc posix)
    minute = String.fromInt (Time.toMinute Time.utc posix)
    second = String.fromInt (Time.toSecond Time.utc posix)
  in
  tr [] [ td [] [ text (day ++ "-" ++ month ++ "-" ++ year ++ " " ++ hour ++ ":" ++ minute ++ ":" ++ second) ]
        , td [] [ text (String.fromFloat transaction.amount) ]
        , td [] [ text transaction.description ]
        , td [] [ text transaction.tags ]
        , td [] [ text transaction.source ]
        ]

viewSummaryStats : Float -> Float -> Float -> Html Msg
viewSummaryStats total avgPerMonth monthsDiff =
  table []
    [ thead []
        [ tr [] [ td [] [ text "Stat" ]
                , td [] [ text "Amount" ]
                ]
        ]
    , tbody []
        [ tr [] [ td [] [ text "Total" ]
                , td [] [ text (String.fromFloat total) ]
                ]
        , tr [] [ td [] [ text "Avg per month" ]
                , td [] [ text (String.fromFloat avgPerMonth) ]
                ]
        , tr [] [ td [] [ text "Months covered" ]
                , td [] [ text (String.fromFloat monthsDiff) ]
                ]
        ]
    ]

getTransactionsQueryParams : Model -> String
getTransactionsQueryParams model =
   String.concat [ "tags="
                , model.tags
                , "&date_from="
                , model.dateFrom
                , "&date_to="
                , model.dateTo
                ]

getTransactions : Model -> Cmd Msg
getTransactions model =
  Http.get
    { url = "http://localhost:4567/all/transactions?" ++ (getTransactionsQueryParams model)
    , expect = Http.expectJson GotTransactions transactionListDecoder
    }

type alias Transaction =
  { id : String
  , date : Int
  , amount : Float
  , description : String
  , tags : String
  , source : String
  }

transactionDecoder : Decoder Transaction
transactionDecoder =
  JD.map6 Transaction
      (field "id" string)
      (field "date" int)
      (field "amount" float)
      (field "description" string)
      (field "tags" string)
      (field "source" string)

transactionListDecoder : Decoder (List Transaction)
transactionListDecoder =
  JD.list transactionDecoder

calcTotal : (List Transaction) -> Float
calcTotal transactionList =
  List.sum (List.map .amount transactionList)

monthInMillis : Float
monthInMillis = (365 * 24 * 60 * 60 * 1000) / 12

calcMonthsDiff : (List Transaction) -> Float
calcMonthsDiff transactionList =
  let sorted = Array.fromList (List.sort (List.map .date transactionList))
      earliest = Maybe.withDefault 0 (Array.get 0 sorted)
      latest = Maybe.withDefault 0 (Array.get ((Array.length sorted) - 1) sorted)
      diff = toFloat (latest - earliest)
      monthsDiff = diff / monthInMillis
  in
  toFloat (ceiling monthsDiff)

calcAvgPerMonth : (List Transaction) -> Float
calcAvgPerMonth transactionList =
  let total = calcTotal transactionList
      monthsDiff = calcMonthsDiff transactionList
  in
  if monthsDiff > 0 then
    total / monthsDiff
  else if monthsDiff == 0 then
    total
  else
    0

toMonthStr : Time.Month -> String
toMonthStr month =
  case month of
    Time.Jan -> "01"
    Time.Feb -> "02"
    Time.Mar -> "03"
    Time.Apr -> "04"
    Time.May -> "05"
    Time.Jun -> "06"
    Time.Jul -> "07"
    Time.Aug -> "08"
    Time.Sep -> "09"
    Time.Oct -> "10"
    Time.Nov -> "11"
    Time.Dec -> "12"
