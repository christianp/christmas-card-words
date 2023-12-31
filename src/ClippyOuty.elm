port module ClippyOuty exposing (..)

import Browser
import File.Download
import Html exposing (Html, div)
import Html.Attributes as HA
import Html.Events as HE
import Json.Decode as JD
import Regex
import Tuple

port imageReceiver : (String -> msg) -> Sub msg

default_image = "christmas-tree.gif"

font_options = 
    [
        "Atkinson Hyperlegible",
        "Baskervville",
        "Berkshire Swash",
        "Calistoga",
        "Cherry Swash",
        "Itim",
        "Kalam",
        "Kalnia",
        "Marcellus",
        "Patua One",
        "Pridi",
        "Quintessential"
    ]

main = Browser.document
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

type alias Model =
    { image_url : String
    , line_width : Float
    , font_size : Float
    , font_family : String
    , text : String
    }

type Msg
    = Noop
    | SetImage String
    | SetLineWidth Float
    | SetFont String
    | SetFontSize Float
    | SetText String
    | WheelMovement Float
    | ReceiveCutout String

init_model : Model
init_model = 
    { image_url = default_image
    , line_width = 60
    , font_size = 15
    , font_family = font_options |> List.head |> Maybe.withDefault "serif"
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

change_suffix : String -> String -> String
change_suffix suffix =
       String.split "."
    >> List.reverse
    >> List.drop 1
    >> (::) suffix
    >> List.reverse
    >> String.join "."

update : Msg -> Model -> (Model, Cmd Msg)
update msg model = case msg of
    Noop -> model |> nocmd
    SetLineWidth w -> { model | line_width = w } |> nocmd
    SetFont font -> { model | font_family = font } |> nocmd
    SetFontSize s -> { model | font_size = s } |> nocmd
    SetText text -> { model | text = text } |> nocmd
    SetImage url -> { model | image_url = url } |> nocmd
    WheelMovement d -> { model | line_width = clamp 1 100 (model.line_width - d/25) |> round |> toFloat } |> nocmd
    ReceiveCutout cutout -> (model, File.Download.string "cutout.svg" "image/svg+xml" (cutout_svg cutout))

cutout_svg cutout = """<?xml version=\"1.0\" encoding="UTF-8" standalone="no"?>\n""" ++ cutout

subscriptions model =
    imageReceiver SetImage

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
        [ Html.div
            [ HA.id "font-loaders" ]
            (List.map (\font -> Html.p [ HA.style "font-family" font ] [ Html.text "hello" ]) font_options)
        , Html.main_ 
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
                    (view_options (List.map (\x -> (x,x)) font_options))


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
            , Html.section
                [HA.id "help" ]
                [ Html.p [] [Html.text "Drag an image file onto this page. Write text in the box. Then draw a mask by dragging with the mouse or pointer."] 
                , Html.p [] [Html.a [ HA.href "https://somethingorotherwhatever.com" ] [ Html.text "Made by clp" ] ]
                ]
            , Html.node "cut-out" 
                [ HA.attribute "source" model.image_url
                , HA.attribute "linewidth" <| String.fromFloat model.line_width
                , HA.attribute "fontsize" <| String.fromFloat model.font_size
                , HA.attribute "fontfamily" model.font_family
                , HA.attribute "text" (clean_text model.text)
                , HE.preventDefaultOn "wheel" (JD.map (\d -> (WheelMovement d,True)) decode_wheel)
                , HE.on "cutout" (JD.map ReceiveCutout decode_cutout)
                ]
                []
            ]
        ]
    }

decode_cutout : JD.Decoder String
decode_cutout = JD.field "detail" JD.string
    
decode_wheel : JD.Decoder Float
decode_wheel = JD.field "deltaY" JD.float
