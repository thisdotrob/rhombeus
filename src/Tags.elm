import Browser
import Html exposing (Html, Attribute, button, div, input, text)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput, onClick)
import Http

main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

type alias Model =
    { content : String }

init : () -> (Model, Cmd Msg)
init _ =
    ({ content = "" }, Cmd.none)

type Msg
    = Change String
    | Submit
    | SavedTags (Result Http.Error String)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        Change newContent ->
            ({ model | content = newContent }, Cmd.none)
        Submit ->
            ({ model | content = "Submitting..." }, (submitTags model.content))
        SavedTags result ->
            case result of
                Ok fullText ->
                    ({ model | content = "Success!" }, Cmd.none)
                Err _ ->
                    ({ model | content = "Failure!" }, Cmd.none)

subscriptions : Model -> Sub Msg
subscriptions model = Sub.none

view : Model -> Html Msg
view model =
    div []
        [ input [ placeholder "Enter new tags", value model.content, onInput Change ] []
        , button [ onClick Submit ] [ text "Submit" ]
        ]

submitTags : String -> Cmd Msg
submitTags tags =
  Http.post
    { url = "http://localhost:4567/tags"
    , expect = Http.expectString SavedTags
    , body = Http.stringBody "text/plain" tags
    }
