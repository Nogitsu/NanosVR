Console.RegisterCommand( "vr_start", function()
    Events.CallRemote( "VR_Start" )
end, "Play nanos in VR !" )

Console.RegisterCommand( "vr_stop", function()
    Events.CallRemote( "VR_Stop" )
end, "Play nanos on Desktop..." )

local childs = {
    Camera = 0,
    RightHand = 1,
    LeftHand = 2,
}

local vr_timer
Events.SubscribeRemote( "EnableVR", function( pawn )
    if not (pawn and pawn:IsValid()) then return end
    pawn:CallBlueprintEvent( "EnableVR" )

    vr_timer = Timer.SetInterval( function()
        if not (pawn and pawn:IsValid()) then return end

        local cam_loc, cam_rot = pawn:CallBlueprintEvent( "GetChildTransform", childs.Camera )
        local r_hand_loc, r_hand_rot = pawn:CallBlueprintEvent( "GetChildTransform", childs.RightHand )
        local l_hand_loc, l_hand_rot = pawn:CallBlueprintEvent( "GetChildTransform", childs.LeftHand )

        pawn:CallRemoteEvent(
            "SyncVR",
            cam_loc, cam_rot,
            r_hand_loc, r_hand_rot,
            l_hand_loc, l_hand_rot,
            pawn:GetBlueprintPropertyValue( "R_HandState" ),
            pawn:GetBlueprintPropertyValue( "L_HandState" )
        )
    end, 100 )
end )

Events.SubscribeRemote( "DisableVR", function( pawn )
    if not (pawn and pawn:IsValid()) then return end
    pawn:CallBlueprintEvent( "DisableVR" )

    if vr_timer and Timer.IsValid( vr_timer ) then
        Timer.ClearInterval( vr_timer )
        vr_timer = nil
    end
end )

Events.SubscribeRemote( "SyncVRHands", function( self, r_hand_state, l_hand_state )
    local ply = self:GetValue( "Player" )
    if not (ply and ply:IsValid()) then return end
    if ply == Client.GetLocalPlayer() then return end

    self:SetBlueprintPropertyValue( "R_HandState", r_hand_state )
    self:SetBlueprintPropertyValue( "L_HandState", l_hand_state )
end )