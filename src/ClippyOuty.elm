module ClippyOuty exposing (..)

import Browser
import Html exposing (Html, div)
import Html.Attributes as HA
import Html.Events as HE
import Json.Decode as JD
import Regex

font_options = 
    [
        ("Atkinson Hyperlegible", "Atkinson Hyperlegible"),
        ("Baskervville", "Baskervville"),
        ("Berkshire Swash", "Berkshire Swash"),
        ("Calistoga", "Calistoga"),
        ("Cherry Swash", "Cherry Swash"),
        ("Itim", "Itim"),
        ("Kalam", "Kalam"),
        ("Kalnia", "Kalnia"),
        ("Marcellus", "Marcellus"),
        ("Patua One", "Patua One"),
        ("Pridi", "Pridi"),
        ("Quintessential", "Quintessential")
    ]

main = Browser.document
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

type alias Model =
    { clips : List String
    , line_width : Float
    , font_size : Float
    , font_family : String
    , text : String
    }

type Msg
    = AddClip String
    | Noop
    | SetLineWidth Float
    | SetFont String
    | SetFontSize Float
    | SetText String

init_model : Model
init_model = 
    { clips = []
    , line_width = 60
    , font_size = 15
    , font_family = "serif"
    , text = "Ho ho ho!"
    }

nocmd model = (model, Cmd.none)

init : () -> (Model, Cmd Msg)
init _ = init_model |> nocmd

clean_text : String -> String
clean_text = 
    Regex.replace 
        ((Regex.fromString "\\s+") |> Maybe.withDefault Regex.never)
        (\_ -> " ")

update : Msg -> Model -> (Model, Cmd Msg)
update msg model = case msg of
    AddClip url -> { model | clips = url::model.clips } |> nocmd
    Noop -> model |> nocmd
    SetLineWidth w -> { model | line_width = w } |> nocmd
    SetFont font -> { model | font_family = font } |> nocmd
    SetFontSize s -> { model | font_size = s } |> nocmd
    SetText text -> { model | text = clean_text text } |> nocmd

subscriptions model = Sub.none

label for text = 
    Html.label
        [ HA.for for ]
        [ Html.text text ]

datalist id options =
    Html.datalist
        [ HA.id id ]
        (view_options options)

view_options : List (String, String) -> List (Html Msg)
view_options = List.map (\(value,text) -> Html.option [ HA.value value ] [ Html.text text ])

onFloatInput msg = HE.onInput (String.toFloat >> Maybe.map msg >> Maybe.withDefault Noop)

view : Model -> Browser.Document Msg
view model = 
    { title = "Clippy outy"
    , body = 
        [ Html.main_ 
            []
            [ Html.section
                [ HA.id "controls" ]
                [ label "line-width" "Radius"
                , Html.input
                    [ HA.type_ "range"
                    , HA.id "line-width"
                    , HA.value <| String.fromFloat <| model.line_width
                    , HA.min "1"
                    , HA.max "100"
                    , HA.list "line-widths"
                    , onFloatInput SetLineWidth
                    ]
                    []
                , Html.output
                    [ HA.for "line-width" ]
                    [ Html.text <| String.fromFloat model.line_width ]
                , datalist "line-widths" [("60","")]

                , label "font" "Font"
                , Html.select
                    [ HE.onInput SetFont
                    ]
                    (view_options font_options)

                , label "font-size" "Font size"
                , Html.input
                    [ HA.type_ "range"
                    , HA.id "font-size"
                    , HA.value <| String.fromFloat <| model.font_size
                    , HA.min "5"
                    , HA.max "50"
                    , HA.list "font-sizes"
                    , onFloatInput SetFontSize
                    ]
                    []
                , Html.output
                    [ HA.for "font-size" ]
                    [ Html.text <| String.fromFloat model.font_size ]
                , datalist "font-sizes" [("15","")]
                ]
            , Html.textarea
                [ HA.id "text"
                , HE.onInput SetText
                , HA.value model.text
                ]
                []
            , Html.node "cut-out" 
                [ HA.attribute "source" (List.head model.clips |> Maybe.withDefault "Christmas Victorian Lady.jpg")
                , HA.attribute "linewidth" <| String.fromFloat model.line_width
                , HA.attribute "fontsize" <| String.fromFloat model.font_size
                , HA.attribute "fontfamily" model.font_family
                , HA.attribute "text" model.text
                , HE.on "cut-out" (decode_cutout |> JD.map AddClip)
                ]
                []
            ]
        ]
    }

decode_cutout : JD.Decoder String
decode_cutout =
    JD.at [ "detail", "clips" ] (JD.list JD.string)
    |> JD.map (List.head)
    |> JD.andThen (Maybe.map (JD.succeed) >> Maybe.withDefault (JD.fail "no clip"))
    
