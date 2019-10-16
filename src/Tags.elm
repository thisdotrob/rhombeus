import Browser
import Html exposing (Html, Attribute, button, div, input, table, tbody, td, text, thead, tr)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput, onClick)
import Http
import Json.Decode as JD exposing (Decoder)

main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

type alias Model =
    { content : String
    , tags : (List String)
    }

init : () -> (Model, Cmd Msg)
init _ =
    ({ content = "" , tags = [] }
    , getTags
    )

type Msg
    = Change String
    | Submit
    | SavedTags (Result Http.Error String)
    | GotTags (Result Http.Error (List String))

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        Change newContent ->
            ({ model | content = newContent }, Cmd.none)
        Submit ->
            ({ model | content = "Submitting..." }, (submitTags model.content))
        SavedTags result ->
            case result of
                Ok _ ->
                    ({ model | content = "Success!" }, getTags)
                Err _ ->
                    ({ model | content = "Failure!" }, Cmd.none)
        GotTags result ->
            case result of
                Ok tags ->
                    ({ model | tags = tags }, Cmd.none)
                Err _ ->
                    ({ model | content = "Failure!" }, Cmd.none)

subscriptions : Model -> Sub Msg
subscriptions model = Sub.none

view : Model -> Html Msg
view model =
    div []
        [ input [ placeholder "Enter new tags", value model.content, onInput Change ] []
        , button [ onClick Submit ] [ text "Submit" ]
        , table [] [ thead [] [ text "Tag" ]
                   , tbody [] (List.map tagRow model.tags)
                   ]
        ]

tagRow : String -> Html Msg
tagRow tag =
    tr [] [ td [] [ text tag ] ]

getTags : Cmd Msg
getTags =
  Http.get
      { url = "http://localhost:4567/tags"
      , expect = Http.expectJson GotTags tagsDecoder
      }

tagsDecoder : Decoder (List String)
tagsDecoder = JD.list tagDecoder

tagDecoder : Decoder String
tagDecoder = JD.field "value" JD.string

submitTags : String -> Cmd Msg
submitTags tags =
  Http.post
      { url = "http://localhost:4567/tags"
      , expect = Http.expectString SavedTags
      , body = Http.stringBody "text/plain" tags
      }
