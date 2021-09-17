module Main exposing (main)

import Bootstrap.Alert as Alert
import Bootstrap.Button as Button
import Bootstrap.Card as Card
import Bootstrap.Card.Block as Block
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Spinner as Spinner
import Bootstrap.Utilities.Flex as Flex
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Browser
import Form
import Html exposing (Html)
import Html.Attributes
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline as P
import List.Extra
import Maybe.Extra
import RemoteData exposing (WebData)
import Round
import Url.Builder


type alias SimulationResult =
    { equityPlayer1 : Float
    , equityPlayer2 : Float
    , equityPlayer3 : Maybe Float
    , equityPlayer4 : Maybe Float
    , equityPlayer5 : Maybe Float
    , equityPlayer6 : Maybe Float
    }


type Position
    = UTG
    | MP
    | CO
    | BU
    | SB
    | BB


type alias SimulationRequestForm =
    { utg : Form.Field String
    , mp : Form.Field String
    , board : Form.Field (Maybe String)
    }


setBoard : String -> SimulationRequestForm -> SimulationRequestForm
setBoard board form =
    if String.isEmpty board then
        { form | board = form.board |> Form.setValue (always (Ok Nothing)) board }

    else
        { form | board = form.board |> Form.setValue (always (Ok (Just board))) board }


setRange : Position -> String -> SimulationRequestForm -> SimulationRequestForm
setRange position range form =
    case position of
        UTG ->
            { form | utg = form.utg |> Form.setValue (always (Ok (String.replace " " "" range))) range }

        MP ->
            { form | mp = form.mp |> Form.setValue (always (Ok (String.replace " " "" range))) range }

        CO ->
            form

        BU ->
            form

        SB ->
            form

        BB ->
            form


initialForm : SimulationRequestForm
initialForm =
    { utg = { name = "UTG", value = "", validated = Ok "" }
    , mp = { name = "MP", value = "", validated = Ok "" }
    , board = { name = "Board", value = "", validated = Ok Nothing }
    }


type alias ResultLine =
    { range : String
    , equity : Float
    }


type alias Model =
    { simulationRequestForm : SimulationRequestForm
    , currentSimulationResult : WebData SimulationResult
    , results : List (List ResultLine)
    }


main : Program () Model Msg
main =
    Browser.document
        { init = \_ -> ( init, Cmd.none )
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }


init : Model
init =
    { simulationRequestForm = initialForm
    , currentSimulationResult = RemoteData.NotAsked
    , results = []
    }


type Msg
    = SimulationRequestSend
    | SimulationResultReceived (WebData SimulationResult)
    | RangeInput Position String
    | BoardInput String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SimulationResultReceived (RemoteData.Success result) ->
            ( { model
                | currentSimulationResult = RemoteData.Success result
              }
            , Cmd.none
            )

        SimulationResultReceived result ->
            ( { model | currentSimulationResult = result }, Cmd.none )

        SimulationRequestSend ->
            let
                validatedRequest =
                    Ok SimulationRequest
                        |> Form.apply model.simulationRequestForm.board.validated
                        |> Form.apply model.simulationRequestForm.utg.validated
                        |> Form.apply model.simulationRequestForm.mp.validated
            in
            case validatedRequest of
                Ok req ->
                    ( { model | currentSimulationResult = RemoteData.Loading }, sendSimulationRequest req )

                Err _ ->
                    ( model, Cmd.none )

        RangeInput position str ->
            ( { model | simulationRequestForm = setRange position str model.simulationRequestForm }, Cmd.none )

        BoardInput str ->
            ( { model | simulationRequestForm = setBoard str model.simulationRequestForm }, Cmd.none )



---- HTTP ----


type alias SimulationRequest =
    { board : Maybe String
    , range1 : String
    , range2 : String
    }


simulationResponseDecoder : Decode.Decoder SimulationResult
simulationResponseDecoder =
    Decode.succeed SimulationResult
        |> P.required "equity_player_1" Decode.float
        |> P.required "equity_player_2" Decode.float
        |> P.required "equity_player_3" (Decode.nullable Decode.float)
        |> P.required "equity_player_4" (Decode.nullable Decode.float)
        |> P.required "equity_player_5" (Decode.nullable Decode.float)
        |> P.required "equity_player_6" (Decode.nullable Decode.float)


sendSimulationRequest : SimulationRequest -> Cmd Msg
sendSimulationRequest request =
    Http.get
        { expect = Http.expectJson (RemoteData.fromResult >> SimulationResultReceived) simulationResponseDecoder
        , url =
            Url.Builder.crossOrigin "https://safe-shore-53897.herokuapp.com"
                [ "simulation" ]
                (Maybe.Extra.toList (request.board |> Maybe.map (Url.Builder.string "board"))
                    ++ [ Url.Builder.string "range1" request.range1
                       , Url.Builder.string "range2" request.range2
                       ]
                )
        }



---- VIEW ----


view : Model -> Browser.Document Msg
view model =
    { title = "Poker Equity Calculator"
    , body =
        [ Html.div []
            [ calculatorView model
            ]
        ]
    }


loadingView : Html Msg
loadingView =
    Html.div []
        [ Html.div [ Flex.block, Flex.row, Flex.alignItemsCenter, Flex.justifyAround ] [ Spinner.spinner [ Spinner.large ] [] ]

        -- , Html.div [ Html.Attributes.align "center", Spacing.mt2 ] [ Html.text "You're request is processing. Sometimes this takes a while. But no worries, susequent requests will be faster. Thanks for your patience." ]
        ]


calculatorView : Model -> Html Msg
calculatorView model =
    Grid.row []
        [ Grid.col []
            [ Card.deck
                [ Card.config []
                    |> Card.headerH4 [] [ Html.text "Poker Equity Calculator" ]
                    |> Card.block []
                        [ Block.custom <|
                            case model.currentSimulationResult of
                                RemoteData.Loading ->
                                    loadingView

                                RemoteData.Failure _ ->
                                    Html.div []
                                        [ Alert.simpleDanger [] [ Html.text "Something went wrong. Please try again." ]
                                        , inputFormView model
                                        ]

                                _ ->
                                    inputFormView model
                        ]

                -- , Card.config []
                --     |> Card.block []
                --         []
                ]
            ]
        ]


equityValue : Position -> Model -> Maybe Float
equityValue position model =
    case model.currentSimulationResult of
        RemoteData.NotAsked ->
            Nothing

        RemoteData.Loading ->
            Nothing

        RemoteData.Failure _ ->
            Nothing

        RemoteData.Success { equityPlayer1, equityPlayer2, equityPlayer3, equityPlayer4, equityPlayer5, equityPlayer6 } ->
            case position of
                UTG ->
                    Just equityPlayer1

                MP ->
                    Just equityPlayer2

                CO ->
                    equityPlayer3

                BU ->
                    equityPlayer4

                SB ->
                    equityPlayer5

                BB ->
                    equityPlayer6


equityValueView : Position -> Model -> Input.Option msg
equityValueView position model =
    case equityValue position model of
        Nothing ->
            Input.value ""

        Just value ->
            Input.value (Round.round 2 (100 * value) ++ " %")


cardToImage : String -> String
cardToImage str =
    String.concat [ "images/", String.toUpper str, ".svg" ]


boardToImages : String -> List String
boardToImages =
    String.toList >> List.Extra.groupsOf 2 >> List.map (String.fromList >> cardToImage)


handRangePlaceholder : String
handRangePlaceholder =
    "Hand Range (e.g. QQ+, AK)"


inputFormView : Model -> Html Msg
inputFormView model =
    Form.form []
        [ Form.row []
            [ Form.col []
                [ Form.group []
                    [ Form.label [] [ Html.text model.simulationRequestForm.utg.name ]
                    , Input.text
                        [ Input.attrs [ Html.Attributes.placeholder handRangePlaceholder ]
                        , Input.value model.simulationRequestForm.utg.value
                        , Input.onInput (RangeInput UTG)
                        ]
                    ]
                ]
            , Form.col [ Col.sm2 ]
                [ Form.group []
                    [ Form.label [] [ Html.text "Equity" ]
                    , Input.text
                        [ Input.readonly True
                        , Input.attrs [ Html.Attributes.tabindex -1 ]
                        , equityValueView UTG model
                        ]
                    ]
                ]
            ]
        , Form.row []
            [ Form.col []
                [ Form.group []
                    [ Form.label [] [ Html.text model.simulationRequestForm.mp.name ]
                    , Input.text
                        [ Input.attrs [ Html.Attributes.placeholder handRangePlaceholder ]
                        , Input.value model.simulationRequestForm.mp.value
                        , Input.onInput (RangeInput MP)
                        ]
                    ]
                ]
            , Form.col [ Col.sm2 ]
                [ Form.group []
                    [ Form.label [] [ Html.text "Equity" ]
                    , Input.text [ Input.readonly True, Input.attrs [ Html.Attributes.tabindex -1 ], equityValueView MP model ]
                    ]
                ]
            ]
        , Form.row
            []
            [ Form.col [ Col.sm10 ]
                [ Form.group []
                    [ Form.label [] [ Html.text model.simulationRequestForm.board.name ]
                    , Input.text
                        [ Input.attrs [ Html.Attributes.placeholder "Board (e.g. 3h4h4c)" ]
                        , Input.value model.simulationRequestForm.board.value
                        , Input.onInput BoardInput
                        ]
                    ]
                ]
            ]

        -- , Form.row [ Row.attrs [ Spacing.mt2 ] ]
        --     [ Form.col [] [ Html.img [ Html.Attributes.src "images/AH.svg", Html.Attributes.width 60 ] [] ]
        --     ]
        , Form.row [ Row.attrs [ Spacing.mt2 ] ]
            [ Form.col []
                [ Button.button
                    [ Button.success
                    , Button.attrs [ Size.w100 ]
                    , Button.onClick SimulationRequestSend
                    ]
                    [ Html.text "Run" ]
                ]
            ]
        ]
