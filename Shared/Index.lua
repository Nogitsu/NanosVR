PawnVR = Blueprint.Inherit("PawnVR")

AttachmentVR = {
    Camera = 0,
    RightHand = 1,
    LeftHand = 2,
}

function PawnVR:Constructor(location, rotation)
    self.Super:Constructor(location, rotation, "nanos-vr::BP_NanosVR")
end

-- Synced Getters
function PawnVR:GetCameraLocation()
    return self:GetValue("CameraLocation", Vector())
end

function PawnVR:GetCameraRotation()
    return self:GetValue("CameraRotation", Rotator())
end

function PawnVR:GetRightHandLocation()
    return self:GetValue("RightHandLocation", Vector())
end

function PawnVR:GetRightHandRotation()
    return self:GetValue("RightHandRotation", Rotator())
end

function PawnVR:GetLeftHandLocation()
    return self:GetValue("LeftHandLocation", Vector())
end

function PawnVR:GetLeftHandRotation()
    return self:GetValue("LeftHandRotation", Rotator())
end

-- Network sync
function PawnVR:IsSynced()
    return Timer.IsValid(self:GetValue("SyncTimer"))
end

function PawnVR:StartSync()
    if Server then return end
    if self:IsSynced() then return end

    local timer = Timer.SetInterval(function()
        if not (self:IsValid() and self:GetValue("Player")) then return end

        local cam_loc, cam_rot = self:CallBlueprintEvent("GetChildTransform", AttachmentVR.Camera)
        local r_hand_loc, r_hand_rot = self:CallBlueprintEvent("GetChildTransform", AttachmentVR.RightHand)
        local l_hand_loc, l_hand_rot = self:CallBlueprintEvent("GetChildTransform", AttachmentVR.LeftHand)

        self:CallRemote(
            "SyncVR",
            cam_loc, cam_rot,
            r_hand_loc, r_hand_rot,
            l_hand_loc, l_hand_rot,
            self:GetBlueprintPropertyValue("R_HandState"),
            self:GetBlueprintPropertyValue("L_HandState")
        )
    end, 100)

    self:SetValue("SyncTimer", timer)
end

function PawnVR:StopSync()
    if self:IsSynced() then
        Timer.ClearInterval(self:GetValue("SyncTimer"))
        self:SetValue("SyncTimer", nil)
    end
end

-- Prediction (Mostly for visuals)
function PawnVR:GetCameraVelocity()
    return self.last_cam_loc and (self:GetCameraLocation() - self.last_cam_loc) / 0.1 or Vector(), self.last_cam_rot and (self:GetCameraRotation() - self.last_cam_rot) / 0.1 or Rotator()
end

function PawnVR:GetRightHandVelocity()
    return self.last_r_hand_loc and (self:GetRightHandLocation() - self.last_r_hand_loc) / 0.1 or Vector(), self.last_r_hand_rot and (self:GetRightHandRotation() - self.last_r_hand_rot) / 0.1 or Rotator()
end

function PawnVR:GetLeftHandVelocity()
    return self.last_l_hand_loc and (self:GetLeftHandLocation() - self.last_l_hand_loc) / 0.1 or Vector(), self.last_l_hand_rot and (self:GetLeftHandRotation() - self.last_l_hand_rot) / 0.1 or Rotator()
end

function PawnVR:UpdateLastTransforms()
    self.last_cam_loc, self.last_cam_rot = self:GetCameraLocation(), self:GetCameraRotation()
    self.last_r_hand_loc, self.last_r_hand_rot = self:GetRightHandLocation(), self:GetRightHandRotation()
    self.last_l_hand_loc, self.last_l_hand_rot = self:GetLeftHandLocation(), self:GetLeftHandRotation()
end


function PawnVR:IsPredicting()
    return Timer.IsValid(self:GetValue("PredictTimer"))
end

function PawnVR:EnablePredicting()
    if Server then return end
    if self:IsPredicting() then return end

    self:UpdateLastTransforms()

    local timer = Timer.SetInterval(function()
        local cam_loc, cam_rot = self:GetCameraLocation(), self:GetCameraRotation()
        local cam_vel, cam_rot_vel = self:GetCameraVelocity()
        local future_cam_loc, future_cam_rot = cam_loc + cam_vel * 0.1, cam_rot + cam_rot_vel * 0.1
        self:CallBlueprintEvent("SetChildTransform", AttachmentVR.Camera, future_cam_loc, future_cam_rot)

        local r_hand_loc, r_hand_rot = self:GetRightHandLocation(), self:GetRightHandRotation()
        local r_hand_vel, r_hand_rot_vel = self:GetRightHandVelocity()
        local future_r_hand_loc, future_r_hand_rot = r_hand_loc + r_hand_vel * 0.1, r_hand_rot + r_hand_rot_vel * 0.1
        self:CallBlueprintEvent("SetChildTransform", AttachmentVR.RightHand, future_r_hand_loc, future_r_hand_rot)

        local l_hand_loc, l_hand_rot = self:GetLeftHandLocation(), self:GetLeftHandRotation()
        local l_hand_vel, l_hand_rot_vel = self:GetLeftHandVelocity()
        local future_l_hand_loc, future_l_hand_rot = l_hand_loc + l_hand_vel * 0.1, l_hand_rot + l_hand_rot_vel * 0.1
        self:CallBlueprintEvent("SetChildTransform", AttachmentVR.LeftHand, future_l_hand_loc, future_l_hand_rot)

        self:UpdateLastTransforms()
    end, 10)

    self:SetValue("PredictTimer", timer)
end

function PawnVR:DisablePredicting()
    if Server then return end
    if not self:IsPredicting() then return end

    Timer.ClearInterval(self:GetValue("PredictTimer"))
    self:SetValue("PredictTimer", nil)
end

-- VR
function PawnVR:EnableVR(ply, no_sync)
    if not self or not self:IsValid() then return end
    if self:GetValue("Player") then return end

    if Server then
        self:SetValue("Player", ply, true)
        ply:SetValue("VRPawn", self, true)

        if not no_sync then
            self:CallRemote("ToggleVR", true)
        end
    else
        self:CallBlueprintEvent("EnableVR")
        self:StartSync()
    end
end

function PawnVR:DisableVR(no_sync)
    if not self or not self:IsValid() then return end
    if not self:GetValue("Player") then return end

    if Server then
        local ply = self:GetValue("Player")
        if ply and ply:IsValid() then
            ply:SetValue("VRPawn", nil, true)
        end

        self:SetValue("Player", nil, true)

        if not no_sync then
            self:CallRemote("ToggleVR", false)
        end
    else
        self:CallBlueprintEvent("DisableVR")
        self:StopSync()
    end
end

-- Network events
if Server then
    PawnVR:SubscribeRemote("Sync", function(self, ply, cam_loc, cam_rot, r_hand_loc, r_hand_rot, l_hand_loc, l_hand_rot, r_hand_state, l_hand_state)
        self:SetValue("CameraLocation", cam_loc, true)
        self:SetValue("CameraRotation", cam_rot, true)
        self:SetValue("RightHandLocation", r_hand_loc, true)
        self:SetValue("RightHandRotation", r_hand_rot, true)
        self:SetValue("LeftHandLocation", l_hand_loc, true)
        self:SetValue("LeftHandRotation", l_hand_rot, true)

        self:BroadcastRemoteEvent("Sync", cam_loc, cam_rot, r_hand_loc, r_hand_rot, l_hand_loc, l_hand_rot, r_hand_state, l_hand_state)
    end)
else
    PawnVR:SubscribeRemote("Sync", function(self, cam_loc, cam_rot, r_hand_loc, r_hand_rot, l_hand_loc, l_hand_rot, r_hand_state, l_hand_state)
        if not self:IsValid() then return end
        local ply = self:GetValue("Player")

        if not (ply and ply:IsValid()) then return end
        if ply == Client.GetLocalPlayer() then return end

        --self:CallBlueprintEvent("SetChildTransform", AttachmentVR.Camera, cam_loc, cam_rot)
        --self:CallBlueprintEvent("SetChildTransform", AttachmentVR.RightHand, r_hand_loc, r_hand_rot)
        --self:CallBlueprintEvent("SetChildTransform", AttachmentVR.LeftHand, l_hand_loc, l_hand_rot)

        self:SetBlueprintPropertyValue("R_HandState", r_hand_state)
        self:SetBlueprintPropertyValue("L_HandState", l_hand_state)
    end)

    PawnVR:SubscribeRemote("ToggleVR", function(self, enable)
        if enable then
            self:EnableVR()
        else
            self:DisableVR()
        end
    end)
end