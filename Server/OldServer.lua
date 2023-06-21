Player.Subscribe( "Ready", function( ply )
    local char = Character( Vector( 0, 0, 100 ), Rotator(), "nanos-world::SK_Mannequin" )
    ply:Possess( char )
end )

for i, v in ipairs( Player.GetAll() ) do
    local char = Character( Vector( 0, 0, 100 ), Rotator(), "nanos-world::SK_Mannequin" )
    v:Possess( char )
end

local childs = {
    Camera = 0,
    RightHand = 1,
    LeftHand = 2,
}

Events.SubscribeRemote( "VR_Start", function( ply )
    local char = ply:GetControlledCharacter()
    if char and char:IsValid() then
        ply:UnPossess()
        char:SetLocation( Vector( 0, 0, -100 ) )
        ply:SetValue( "Desktop_Char", char )
    end

    local pawn = Blueprint( Vector( 0, 0, 100 ), char and char:GetRotation() or Rotator(), "nanos-vr::BP_NanosVR" )
    pawn:SetValue( "Player", ply, true )
    ply:SetValue( "VR_Pawn", pawn, true )

    pawn:SubscribeRemote( "SyncVR", function( self, ply, cam_loc, cam_rot, r_hand_loc, r_hand_rot, l_hand_loc, l_hand_rot, r_hand_state, l_hand_state )
        self:CallBlueprintEvent( "SetChildTransform", childs.Camera, cam_loc, cam_rot )
        self:CallBlueprintEvent( "SetChildTransform", childs.RightHand, r_hand_loc, r_hand_rot )
        self:CallBlueprintEvent( "SetChildTransform", childs.LeftHand, l_hand_loc, l_hand_rot )

        Events.BroadcastRemote( "SyncVRHands", self, r_hand_state, l_hand_state )
    end )

    Events.CallRemote( "EnableVR", ply, pawn )
end )

Events.SubscribeRemote( "VR_Stop", function( ply )
    local pawn = ply:GetValue( "VR_Pawn" )
    local char = ply:GetValue( "Desktop_Char" )

    if char and char:IsValid() then
        ply:Possess( char )
        char:SetLocation(  Vector( 0, 0, 100 ) )
        ply:SetValue( "Desktop_Char", nil )
    end

    if pawn and pawn:IsValid() then
        Events.CallRemote( "DisableVR", ply, pawn )
        pawn:Destroy()
        ply:SetValue( "VR_Pawn", nil, true )
    end
end )