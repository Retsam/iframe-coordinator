module HostProgram exposing (create, Model, Msg)

{-| The FrameRouter module is the Elm code that backs the frame-router custom element
in the iframe-coordinator toolkit. It handles mapping URL routes to clients displayed
in a child frame as well as message validation and routing within the parent application.

This module is not currently designed for stand-alone use. You should instead use the
custom elements defined in LINK_TO_JS_LIB to create seamless iframe applications

@docs createRouter

-}

import ClientRegistry exposing (Client, ClientRegistry)
import Html exposing (Attribute, Html)
import Html.Attributes exposing (attribute)
import Json.Decode as Decode exposing (decodeValue)
import ClientMessage exposing (ClientMessage)
import Navigation exposing (Location)
import Path exposing (Path)


{-| Create a program to handle routing. Takes an input port to listen to messages on.
port binding is handled in the custom frame-router element in LINK_TO_JS_LIB_HERE
-}
create : ((Decode.Value -> Msg) -> Sub Msg) -> Program Decode.Value Model Msg
create inputPort =
    Navigation.programWithFlags
        (RouteChange << parseLocation)
        { init = init
        , update = update
        , view = view
        , subscriptions =
            \_ ->
                inputPort decodeClientMsg
        }



-- Model


type alias Model =
    { clients : ClientRegistry
    , route : Path
    }


init : Decode.Value -> Location -> ( Model, Cmd Msg )
init clientJson location =
    ( { clients = ClientRegistry.decode clientJson
      , route = parseLocation location
      }
    , Cmd.none
    )



-- Update


type Msg
    = RouteChange Path
    | ClientMsg ClientMessage
    | Unknown String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RouteChange route ->
            ( { model | route = route }, Cmd.none )

        ClientMsg msg ->
            handleClientMsg model msg

        Unknown err ->
            ( model, logWarning ("Unknown Msg: " ++ err) )


handleClientMsg : Model -> ClientMessage -> ( Model, Cmd Msg )
handleClientMsg model msg =
    case msg of
        ClientMessage.NavRequest location ->
            ( model, Navigation.newUrl location.hash )


parseLocation : Location -> Path
parseLocation location =
    String.dropLeft 1 location.hash
        |> Path.parse


logWarning : String -> Cmd Msg
logWarning errMsg =
    let
        _ =
            Debug.log errMsg
    in
    Cmd.none



-- View


view : Model -> Html Msg
view model =
    clientFrame [ src (url model.clients model.route) ] []


url : ClientRegistry -> Path -> String
url registry route =
    ClientRegistry.urlForRoute registry route
        |> Maybe.withDefault "about:blank"


clientFrame : List (Attribute msg) -> List (Html msg) -> Html msg
clientFrame =
    Html.node "x-ifc-frame"


src : String -> Attribute msg
src value =
    attribute "src" value



-- Subs


decodeClientMsg : Decode.Value -> Msg
decodeClientMsg json =
    case
        Decode.decodeValue
            (Decode.map ClientMsg ClientMessage.decoder)
            json
    of
        Ok msg ->
            msg

        Err err ->
            Unknown err