TMG.Phone.Settings = {};
TMG.Phone.Settings.Background = "default-qbcore";
TMG.Phone.Settings.OpenedTab = null;
TMG.Phone.Settings.Backgrounds = {
    'default-qbcore': { label: "Standard TMGCore" }
};

var PressedBackground = null;
var PressedBackgroundObject = null;
var OldBackground = null;
var IsChecked = null;

$(document).on('click', '.settings-app-tab', function(e){
    e.preventDefault();
    var PressedTab = $(this).data("settingstab");
    if (PressedTab == "background" || PressedTab == "profilepicture") {
        TMG.Phone.Animations.TopSlideDown(".settings-"+PressedTab+"-tab", 200, 0);
        TMG.Phone.Settings.OpenedTab = PressedTab;
    } else if (PressedTab == "numberrecognition") {
        var checkBoxes = $(".numberrec-box");
        TMG.Phone.Data.AnonymousCall = !checkBoxes.prop("checked");
        checkBoxes.prop("checked", TMG.Phone.Data.AnonymousCall);
        if (!TMG.Phone.Data.AnonymousCall) {
            $("#numberrecognition > p").html('Off');
        } else {
            $("#numberrecognition > p").html('On');
        }
    }
});

$(document).on("click", "#phoneNumberSelect, #serialNumberSelect", function (e) {
    var title = $(this).attr("id") == "phoneNumberSelect" ? "Phone Number" : "Serial Number";
    var textToCopy = $(this).attr("id") == "phoneNumberSelect" ? $("#myPhoneNumber").text() : $("#mySerialNumber").text();
    var clipboard = new ClipboardJS(this, {
        text: function () {
            TMG.Phone.Notifications.Add("fas fa-phone", "Copied " + title + "!", textToCopy);
            return textToCopy;
        }
    });
});

$(document).on('click', '#accept-background', function(e){
    e.preventDefault();
    var hasCustomBackground = TMG.Phone.Functions.IsBackgroundCustom();
    if (hasCustomBackground === false) {
        TMG.Phone.Notifications.Add("fas fa-paint-brush", "Settings", TMG.Phone.Settings.Backgrounds[TMG.Phone.Settings.Background].label+" is set!");
        TMG.Phone.Animations.TopSlideUp(".settings-"+TMG.Phone.Settings.OpenedTab+"-tab", 200, -100);
        $(".phone-background").css({"background-image":"url('/html/img/backgrounds/"+TMG.Phone.Settings.Background+".png')"});
    } else {
        TMG.Phone.Notifications.Add("fas fa-paint-brush", "Settings", "Personal background set!");
        TMG.Phone.Animations.TopSlideUp(".settings-"+TMG.Phone.Settings.OpenedTab+"-tab", 200, -100);
        $(".phone-background").css({"background-image":"url('"+TMG.Phone.Settings.Background+"')"});
    }
    $.post('https://tmg-phone/SetBackground', JSON.stringify({
        background: TMG.Phone.Settings.Background,
    }));
});

TMG.Phone.Functions.LoadMetaData = function(MetaData) {
    if (MetaData.background !== null && MetaData.background !== undefined) {
        TMG.Phone.Settings.Background = MetaData.background;
    } else {
        TMG.Phone.Settings.Background = "default-qbcore";
    }
    var hasCustomBackground = TMG.Phone.Functions.IsBackgroundCustom();
    if (!hasCustomBackground) {
        $(".phone-background").css({"background-image":"url('/html/img/backgrounds/"+TMG.Phone.Settings.Background+".png')"});
    } else {
        $(".phone-background").css({"background-image":"url('"+TMG.Phone.Settings.Background+"')"});
    }
    if (MetaData.profilepicture == "default" || !MetaData.profilepicture) {
        $("[data-settingstab='profilepicture']").find('.settings-tab-icon').html('<img src="./img/default.png">');
    } else {
        $("[data-settingstab='profilepicture']").find('.settings-tab-icon').html('<img src="'+MetaData.profilepicture+'">');
    }
};

$(document).on('click', '#cancel-background', function(e){
    e.preventDefault();
    TMG.Phone.Animations.TopSlideUp(".settings-"+TMG.Phone.Settings.OpenedTab+"-tab", 200, -100);
});

TMG.Phone.Functions.IsBackgroundCustom = function() {
    var retval = true;
    $.each(TMG.Phone.Settings.Backgrounds, function(i, background){
        if (TMG.Phone.Settings.Background == i) {
            retval = false;
        }
    });
    return retval;
};

$(document).on('click', '.background-option', function(e){
    e.preventDefault();
    PressedBackground = $(this).data('background');
    PressedBackgroundObject = this;
    OldBackground = $(this).parent().find('.background-option-current');
    IsChecked = $(this).find('.background-option-current');
    if (IsChecked.length === 0) {
        if (PressedBackground != "custom-background") {
            TMG.Phone.Settings.Background = PressedBackground;
            $(OldBackground).fadeOut(50, function(){
                $(OldBackground).remove();
            });
            $(PressedBackgroundObject).append('<div class="background-option-current"><i class="fas fa-check-circle"></i></div>');
        } else {
            TMG.Phone.Animations.TopSlideDown(".background-custom", 200, 13);
        }
    }
});

$(document).on('click', '#accept-custom-background', function(e){
    e.preventDefault();
    TMG.Phone.Settings.Background = $(".custom-background-input").val();
    $(OldBackground).fadeOut(50, function(){
        $(OldBackground).remove();
    });
    $(PressedBackgroundObject).append('<div class="background-option-current"><i class="fas fa-check-circle"></i></div>');
    TMG.Phone.Animations.TopSlideUp(".background-custom", 200, -23);
});

$(document).on('click', '#cancel-custom-background', function(e){
    e.preventDefault();
    TMG.Phone.Animations.TopSlideUp(".background-custom", 200, -23);
});

// Profile Picture
var PressedProfilePicture = null;
var PressedProfilePictureObject = null;
var OldProfilePicture = null;
var ProfilePictureIsChecked = null;

$(document).on('click', '#accept-profilepicture', function(e){
    e.preventDefault();
    var ProfilePicture = TMG.Phone.Data.MetaData.profilepicture;
    if (ProfilePicture === "default") {
        TMG.Phone.Notifications.Add("fas fa-paint-brush", "Settings", "Standard avatar set!");
        TMG.Phone.Animations.TopSlideUp(".settings-"+TMG.Phone.Settings.OpenedTab+"-tab", 200, -100);
        $("[data-settingstab='profilepicture']").find('.settings-tab-icon').html('<img src="./img/default.png">');
    } else {
        TMG.Phone.Notifications.Add("fas fa-paint-brush", "Settings", "Personal avatar set!");
        TMG.Phone.Animations.TopSlideUp(".settings-"+TMG.Phone.Settings.OpenedTab+"-tab", 200, -100);
        $("[data-settingstab='profilepicture']").find('.settings-tab-icon').html('<img src="'+ProfilePicture+'">');
    }
    $.post('https://tmg-phone/UpdateProfilePicture', JSON.stringify({
        profilepicture: ProfilePicture,
    }));
});

$(document).on('click', '#accept-custom-profilepicture', function(e){
    e.preventDefault();
    TMG.Phone.Data.MetaData.profilepicture = $(".custom-profilepicture-input").val();
    $(OldProfilePicture).fadeOut(50, function(){
        $(OldProfilePicture).remove();
    });
    $(PressedProfilePictureObject).append('<div class="profilepicture-option-current"><i class="fas fa-check-circle"></i></div>');
    TMG.Phone.Animations.TopSlideUp(".profilepicture-custom", 200, -23);
});

$(document).on('click', '.profilepicture-option', function(e){
    e.preventDefault();
    PressedProfilePicture = $(this).data('profilepicture');
    PressedProfilePictureObject = this;
    OldProfilePicture = $(this).parent().find('.profilepicture-option-current');
    ProfilePictureIsChecked = $(this).find('.profilepicture-option-current');
    if (ProfilePictureIsChecked.length === 0) {
        if (PressedProfilePicture != "custom-profilepicture") {
            TMG.Phone.Data.MetaData.profilepicture = PressedProfilePicture;
            $(OldProfilePicture).fadeOut(50, function(){
                $(OldProfilePicture).remove();
            });
            $(PressedProfilePictureObject).append('<div class="profilepicture-option-current"><i class="fas fa-check-circle"></i></div>');
        } else {
            TMG.Phone.Animations.TopSlideDown(".profilepicture-custom", 200, 13);
        }
    }
});

$(document).on('click', '#cancel-profilepicture', function(e){
    e.preventDefault();
    TMG.Phone.Animations.TopSlideUp(".settings-"+TMG.Phone.Settings.OpenedTab+"-tab", 200, -100);
});

$(document).on('click', '#cancel-custom-profilepicture', function(e){
    e.preventDefault();
    TMG.Phone.Animations.TopSlideUp(".profilepicture-custom", 200, -23);
});