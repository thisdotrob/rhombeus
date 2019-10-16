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
    , tags : (List Tag)
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
    | GotTags (Result Http.Error (List Tag))
    | Delete Tag
    | DeletedTag (Result Http.Error String)

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
        Delete tag ->
                    ({ model | content = "Deleting..." }, (deleteTag tag))
        DeletedTag result ->
            case result of
                Ok _ ->
                    ({ model | content = "Success!" }, getTags)
                Err _ ->
                    ({ model | content = "Failure!" }, Cmd.none)



subscriptions : Model -> Sub Msg
subscriptions model = Sub.none

view : Model -> Html Msg
view model =
    div []
        [ input [ placeholder "Enter new tags", value model.content, onInput Change ] []
        , button [ onClick Submit ] [ text "Submit" ]
        , table [] [ tbody [] (List.map tagRow model.tags) ]
        ]

tagRow : Tag -> Html Msg
tagRow tag =
    tr [] [ td [] [ text tag.value
                  , button [ onClick (Delete tag) ] [ text "X" ] ] ]

getTags : Cmd Msg
getTags =
  Http.get
      { url = "http://localhost:4567/tags"
      , expect = Http.expectJson GotTags tagsDecoder
      }

type alias Tag =
    { value : String
    , id : String
    }

tagsDecoder : Decoder (List Tag)
tagsDecoder = JD.list tagDecoder

tagDecoder : Decoder Tag
tagDecoder = JD.map2 Tag
             (JD.field "value" JD.string)
             (JD.field "id" JD.string)

submitTags : String -> Cmd Msg
submitTags tags =
  Http.post
      { url = "http://localhost:4567/tags"
      , expect = Http.expectString SavedTags
      , body = Http.stringBody "text/plain" tags
      }

deleteTag : Tag -> Cmd Msg
deleteTag tag =
    Http.post
        { url = "http://localhost:4567/delete_tag"
        , expect = Http.expectString DeletedTag
        , body = Http.stringBody "text/plain" tag.id
        }
