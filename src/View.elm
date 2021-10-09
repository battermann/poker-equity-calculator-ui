module View exposing (view)

import Bootstrap.Alt.Alert as Alert
import Bootstrap.Alt.Popover as Popover
import Bootstrap.Button as Button
import Bootstrap.Card as Card
import Bootstrap.Card.Block as Block
import Bootstrap.Dropdown as Dropdown
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.InputGroup as InputGroup
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Spinner as Spinner
import Bootstrap.Utilities.Flex as Flex
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Browser
import Form
import Form.Field exposing (Field)
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Model exposing (Model, Msg(..), PopoverStates, ResultLine)
import Poker.Card as Card
import Poker.HandOrCombo exposing (HandOrCombo)
import Poker.Position as Position exposing (Position(..))
import Poker.Ranges as Ranges
import Poker.Suit exposing (Suit(..))
import Ports exposing (SharingType(..))
import RemoteData
import Result.Extra
import Round
import Url.Builder
import Views.Board
import Views.Modal.Board
import Views.Modal.Range
import Views.RangePercentage
import Views.Result


view : Model -> Browser.Document Msg
view model =
    { title = "Equiweb"
    , body =
        [ Grid.container []
            [ formView model
            , Views.Modal.Board.view model
            , Views.Modal.Range.view model
            ]
        ]
    }


loadingView : Html Msg
loadingView =
    Html.div [ Html.Attributes.class "loading-view" ]
        [ Html.div [ Flex.block, Flex.row, Flex.alignItemsCenter, Flex.justifyAround ] [ Spinner.spinner [ Spinner.large ] [] ]
        ]


formView : Model -> Html Msg
formView model =
    Grid.row []
        [ Grid.col []
            [ Card.deck
                ((Card.config [ Card.attrs [ Spacing.mb3, Html.Attributes.class "shadow" ] ]
                    |> Card.headerH2 []
                        [ Html.div [ Flex.block, Flex.row, Flex.justifyBetween ]
                            [ Html.a [ Html.Attributes.href (Url.Builder.absolute [] []), Flex.block, Flex.row, Flex.alignItemsStart ]
                                [ Html.img [ Html.Attributes.src "images/chip-icon.svg", Html.Attributes.width 40 ] []
                                , Html.div [ Html.Attributes.style "margin-top" "auto", Html.Attributes.style "margin-left" "7px", Html.Attributes.style "margin-bottom" "auto" ] [ Html.text "Equiweb" ]
                                ]
                            ]
                        ]
                    |> Card.block []
                        [ Block.custom <|
                            case model.currentApiResponse of
                                RemoteData.Loading ->
                                    Html.div [] [ loadingView, inputFormView model ]

                                RemoteData.Failure _ ->
                                    inputFormView model

                                _ ->
                                    inputFormView model
                        ]
                 )
                    :: (model.results |> List.reverse |> List.indexedMap (\index ( popoverStates, _, res ) -> Views.Result.view index popoverStates res))
                )
            ]
        ]


equityValueView : Maybe ResultLine -> Input.Option msg
equityValueView result =
    case result of
        Nothing ->
            Input.value ""

        Just value ->
            Input.value (Round.round 2 (100 * value.equity) ++ " %")


validationFeedbackOutline : Field a -> List (Input.Option msg)
validationFeedbackOutline field =
    case ( field.validated, field.edited ) of
        ( Ok _, True ) ->
            [ Input.success ]

        ( Err _, True ) ->
            [ Input.danger ]

        _ ->
            []


inputFormView : Model -> Html Msg
inputFormView model =
    Form.form []
        [ rangeInputView (Model.popoverState UTG model) UTG (Form.rangeField UTG model.form) (model.currentApiResponse |> RemoteData.map .utg |> RemoteData.toMaybe |> Maybe.andThen identity) model.rangeDropdownStateUtg (Ranges.positionalRanges |> List.filter (.position >> (==) UTG) |> List.map (\pr -> ( pr.label, pr.range )))
        , rangeInputView (Model.popoverState MP model) MP (Form.rangeField MP model.form) (model.currentApiResponse |> RemoteData.map .mp |> RemoteData.toMaybe |> Maybe.andThen identity) model.rangeDropdownStateMp (Ranges.positionalRanges |> List.filter (.position >> (==) MP) |> List.map (\pr -> ( pr.label, pr.range )))
        , rangeInputView (Model.popoverState CO model) CO (Form.rangeField CO model.form) (model.currentApiResponse |> RemoteData.map .co |> RemoteData.toMaybe |> Maybe.andThen identity) model.rangeDropdownStateCo (Ranges.positionalRanges |> List.filter (.position >> (==) CO) |> List.map (\pr -> ( pr.label, pr.range )))
        , rangeInputView (Model.popoverState BU model) BU (Form.rangeField BU model.form) (model.currentApiResponse |> RemoteData.map .bu |> RemoteData.toMaybe |> Maybe.andThen identity) model.rangeDropdownStateBu (Ranges.positionalRanges |> List.filter (.position >> (==) BU) |> List.map (\pr -> ( pr.label, pr.range )))
        , rangeInputView (Model.popoverState SB model) SB (Form.rangeField SB model.form) (model.currentApiResponse |> RemoteData.map .sb |> RemoteData.toMaybe |> Maybe.andThen identity) model.rangeDropdownStateSb (Ranges.positionalRanges |> List.filter (.position >> (==) SB) |> List.map (\pr -> ( pr.label, pr.range )))
        , rangeInputView (Model.popoverState BB model) BB (Form.rangeField BB model.form) (model.currentApiResponse |> RemoteData.map .bb |> RemoteData.toMaybe |> Maybe.andThen identity) model.rangeDropdownStateBb (Ranges.positionalRanges |> List.filter (.position >> (==) BB) |> List.map (\pr -> ( pr.label, pr.range )))
        , Form.row
            []
            [ Form.col [ Col.sm10 ]
                [ Form.group []
                    [ Form.label [] [ Html.text (Form.boardField model.form).name ]
                    , InputGroup.config
                        (InputGroup.text
                            (validationFeedbackOutline (Form.boardField model.form)
                                ++ [ Input.value (Form.boardField model.form).value
                                   , Input.onInput BoardInput
                                   ]
                            )
                        )
                        |> InputGroup.attrs
                            (if (Form.boardField model.form).validated |> Result.Extra.isOk then
                                [ Html.Attributes.class "is-valid" ]

                             else
                                [ Html.Attributes.class "is-invalid" ]
                            )
                        |> InputGroup.predecessors
                            [ InputGroup.span [ Html.Attributes.class "tooltip-wrapper" ]
                                [ Popover.config
                                    (Button.button
                                        [ Button.outlineSecondary
                                        , Button.onClick ShowBoardSelectModal
                                        , Button.attrs (Html.Attributes.tabindex -1 :: Popover.onHover model.popoverStateBoard PopoverStateBoard)
                                        ]
                                        [ Html.img [ Html.Attributes.src "images/apps_black_24dp.svg", Html.Attributes.width 20 ] [] ]
                                    )
                                    |> Popover.top
                                    |> Popover.content []
                                        [ Html.text "Open Board Dialog" ]
                                    |> Popover.view model.popoverStateBoard
                                ]
                            , InputGroup.span [ Html.Attributes.class "tooltip-wrapper" ]
                                [ Popover.config
                                    (Html.div (Popover.onHover model.popoverStateClearBoard PopoverStateClearBoard)
                                        [ Button.button
                                            [ Button.outlineSecondary
                                            , Button.attrs [ Html.Attributes.tabindex -1 ]
                                            , Button.onClick RemoveBoard
                                            , Button.disabled ((Form.boardField model.form).value |> String.isEmpty)
                                            ]
                                            [ Html.i [ Html.Attributes.class "far fa-trash-alt" ] [] ]
                                        ]
                                    )
                                    |> Popover.top
                                    |> Popover.content []
                                        [ Html.text "Clear Board" ]
                                    |> Popover.view model.popoverStateClearBoard
                                ]
                            ]
                        |> InputGroup.view
                    , Form.invalidFeedback [] [ Html.text "The board is not a valid board" ]
                    ]
                ]
            ]
        , if (Form.boardField model.form).validated == Ok [] then
            Html.text ""

          else
            Form.row [ Row.attrs [ Spacing.mt2 ] ] [ Form.col [] [ Button.button [ Button.light, Button.onClick ShowBoardSelectModal ] [ Views.Board.view True "pointer" "6vw" (Form.board model.form) ] ] ]
        , if (Form.ranges model.form |> List.length) < 2 then
            Alert.simpleInfo [ Spacing.mt2 ] [ Html.text "You must fill in at least 2 ranges." ]

          else
            Html.text ""
        , Form.row [ Row.attrs [ Spacing.mt2 ] ]
            [ Form.col []
                [ Html.div [ Flex.block, Flex.row ]
                    [ Button.linkButton
                        [ Button.light
                        , Button.attrs [ Size.w100, Html.Attributes.style "margin-right" "2px", Html.Attributes.href (Url.Builder.absolute [] []) ]
                        ]
                        [ Html.text "CLEAR ALL" ]
                    , Button.button
                        [ Button.success
                        , Button.attrs [ Size.w100, Html.Attributes.style "margin-left" "2px" ]
                        , Button.onClick SendSimulationRequest
                        ]
                        [ Html.text "RUN" ]
                    ]
                ]
            ]
        , Form.row [ Row.attrs [ Spacing.mt2 ] ] [ Form.col [ Col.md12 ] [ Html.div [ Html.Attributes.style "text-align" "end", Size.w100 ] [ Html.a [ Html.Attributes.href "https://docs.google.com/forms/d/e/1FAIpQLSdz078OCo4gZikCRU7EDc4BS1NYFWfXioXBPK06_ZL_7BQ4sw/viewform", Html.Attributes.target "blank" ] [ Html.i [ Html.Attributes.class "fas fa-external-link-alt", Html.Attributes.style "margin-right" "2px" ] [], Html.text "report a bug or leave feedback" ] ] ] ]
        ]


rangeInputView : PopoverStates -> Position -> Field (List HandOrCombo) -> Maybe ResultLine -> Dropdown.State -> List ( String, String ) -> Html Msg
rangeInputView popoverStates position field result dropdownState ranges =
    Form.row []
        [ Form.col []
            [ Form.group []
                ([ Form.label []
                    [ Html.text field.name ]
                 , InputGroup.config
                    (InputGroup.text
                        (validationFeedbackOutline field
                            ++ [ Input.value field.value
                               , Input.onInput (RangeInput position)
                               ]
                        )
                    )
                    |> InputGroup.attrs
                        [ if field.validated |> Result.Extra.isOk then
                            Html.Attributes.class "is-valid"

                          else
                            Html.Attributes.class "is-invalid"
                        ]
                    |> InputGroup.predecessors
                        [ InputGroup.span [ Html.Attributes.class "tooltip-wrapper" ]
                            [ Popover.config
                                (Dropdown.dropdown
                                    dropdownState
                                    { options = [ Dropdown.attrs (Popover.onHover popoverStates.rangeSelect (PopoverStateSelectRange position)) ]
                                    , toggleMsg = RangeDropdownMsg position
                                    , toggleButton =
                                        Dropdown.toggle [ Button.outlineSecondary, Button.attrs [ Html.Attributes.tabindex -1 ] ] [ Html.i [ Html.Attributes.class "fas fa-bars" ] [] ]
                                    , items =
                                        ranges
                                            |> List.map
                                                (\( label, range ) ->
                                                    Dropdown.buttonItem [ Html.Events.onClick (SelectPresetRange position range) ] [ Html.text label ]
                                                )
                                    }
                                )
                                |> Popover.top
                                |> Popover.content []
                                    [ Html.text "Select Range" ]
                                |> Popover.view popoverStates.rangeSelect
                            ]
                        , InputGroup.span [ Html.Attributes.class "tooltip-wrapper", Html.Attributes.class "z-index-0" ]
                            [ Popover.config
                                (Button.button
                                    [ Button.outlineSecondary
                                    , Button.onClick (ShowRangeSelectionModal position)
                                    , Button.attrs ([ Html.Attributes.tabindex -1, Html.Attributes.type_ "button" ] ++ Popover.onHover popoverStates.openGrid (PopoverStateOpenGrid position))
                                    ]
                                    [ Html.img [ Html.Attributes.src "images/apps_black_24dp.svg", Html.Attributes.height 22 ] [] ]
                                )
                                |> Popover.top
                                |> Popover.content []
                                    [ Html.text "Open Grid Dialog" ]
                                |> Popover.view popoverStates.openGrid
                            ]
                        , InputGroup.span [ Html.Attributes.class "tooltip-wrapper", Html.Attributes.class "z-index-0" ]
                            [ Popover.config
                                (Html.div (Popover.onHover popoverStates.normalize (PopoverStateNormalize position))
                                    [ Button.button
                                        [ Button.outlineSecondary
                                        , Button.onClick (RewriteRange position)
                                        , Button.disabled (Form.rewritable field |> not)
                                        , Button.attrs [ Html.Attributes.tabindex -1 ]
                                        ]
                                        [ Html.img [ Html.Attributes.src "images/auto_fix_high_black_24dp.svg", Html.Attributes.height 20 ] [] ]
                                    ]
                                )
                                |> Popover.top
                                |> Popover.content []
                                    [ Html.text "Normalize Range" ]
                                |> Popover.view popoverStates.normalize
                            ]
                        , InputGroup.span [ Html.Attributes.class "tooltip-wrapper", Html.Attributes.class "z-index-0" ]
                            [ Popover.config
                                (Html.div (Popover.onHover popoverStates.clear (PopoverStateClear position))
                                    [ Button.button
                                        [ Button.outlineSecondary
                                        , Button.attrs [ Html.Attributes.tabindex -1 ]
                                        , Button.onClick (RemoveRange position)
                                        , Button.disabled (field.value |> String.isEmpty)
                                        ]
                                        [ Html.i [ Html.Attributes.class "far fa-trash-alt" ] [] ]
                                    ]
                                )
                                |> Popover.top
                                |> Popover.content []
                                    [ Html.text "Clear Range" ]
                                |> Popover.view popoverStates.clear
                            ]
                        ]
                    |> InputGroup.view
                 ]
                    ++ Views.RangePercentage.viewIfNotEmpty (field.validated |> Result.withDefault [])
                    ++ [ Form.invalidFeedback [] [ Html.text ("The " ++ Position.toString position ++ " range is not a valid range") ] ]
                )
            ]
        , Form.col [ Col.sm2 ]
            [ Form.group []
                [ Form.label [] [ Html.text "Equity" ]
                , Input.text [ Input.readonly True, Input.attrs [ Html.Attributes.tabindex -1 ], equityValueView result ]
                ]
            ]
        ]