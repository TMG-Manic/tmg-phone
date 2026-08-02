TMG = {}
TMG.Phone = {}
TMG.Screen = {}
TMG.Phone.Functions = {}
TMG.Phone.Animations = {}
TMG.Phone.Notifications = {}
TMG.Phone.ContactColors = {
    0: "#9b59b6",
    1: "#3498db",
    2: "#e67e22",
    3: "#e74c3c",
    4: "#1abc9c",
    5: "#9c88ff",
}

TMG.Phone.Data = {
    currentApplication: null,
    PlayerData: {},
    Applications: {},
    IsOpen: false,
    CallActive: false,
    MetaData: {},
    PlayerJob: {},
    AnonymousCall: false,
}

TMG.Phone.Data.MaxSlots = 16;

OpenedChatData = {
    number: null,
}

var CanOpenApp = true;
var up = false

function IsAppJobBlocked(joblist, myjob) {
    var retval = false;
    if (joblist.length > 0) {
        $.each(joblist, function(i, job){
            if (job == myjob && TMG.Phone.Data.PlayerData.job.onduty) {
                retval = true;
            }
        });
    }
    return retval;
}

TMG.Phone.Functions.SetupApplications = function(data) {
    TMG.Phone.Data.Applications = data.applications;

    var i;
    for (i = 1; i <= TMG.Phone.Data.MaxSlots; i++) {
        var applicationSlot = $(".phone-applications").find('[data-appslot="'+i+'"]');
        $(applicationSlot).html("");
        $(applicationSlot).css({
            "background-color":"transparent"
        });
        $(applicationSlot).prop('title', "");
        $(applicationSlot).removeData('app');
        $(applicationSlot).removeData('placement')
    }

    $.each(data.applications, function(i, app){
        var applicationSlot = $(".phone-applications").find('[data-appslot="'+app.slot+'"]');
        var blockedapp = IsAppJobBlocked(app.blockedjobs, TMG.Phone.Data.PlayerJob.name)

        if ((!app.job || app.job === TMG.Phone.Data.PlayerJob.name) && !blockedapp) {
            $(applicationSlot).css({"background-color":app.color});
            var icon = '<i class="ApplicationIcon '+app.icon+'" style="'+app.style+'"></i>';
            if (app.app == "meos") {
                icon = '<img src="./img/politie.png" class="police-icon">';
            }
            $(applicationSlot).html(icon+'<div class="app-unread-alerts">0</div>');
            $(applicationSlot).prop('title', app.tooltipText);
            $(applicationSlot).data('app', app.app);

            if (app.tooltipPos !== undefined) {
                $(applicationSlot).data('placement', app.tooltipPos)
            }
        }
    });

    $('[data-toggle="tooltip"]').tooltip();
}

TMG.Phone.Functions.SetupAppWarnings = function(AppData) {
    $.each(AppData, function(i, app){
        var AppObject = $(".phone-applications").find("[data-appslot='"+app.slot+"']").find('.app-unread-alerts');

        if (app.Alerts > 0) {
            $(AppObject).html(app.Alerts);
            $(AppObject).css({"display":"block"});
        } else {
            $(AppObject).css({"display":"none"});
        }
    });
}

TMG.Phone.Functions.IsAppHeaderAllowed = function(app) {
    var retval = true;
    $.each(Config.HeaderDisabledApps, function(i, blocked){
        if (app == blocked) {
            retval = false;
        }
    });
    return retval;
}

$(document).on('click', '.phone-application', function(e){
    e.preventDefault();
    var PressedApplication = $(this).data('app');
    var AppObject = $("."+PressedApplication+"-app");

    if (AppObject.length !== 0) {
        if (CanOpenApp) {
            if (TMG.Phone.Data.currentApplication == null) {
                TMG.Phone.Animations.TopSlideDown('.phone-application-container', 300, 0);
                TMG.Phone.Functions.ToggleApp(PressedApplication, "block");

                if (TMG.Phone.Functions.IsAppHeaderAllowed(PressedApplication)) {
                    TMG.Phone.Functions.HeaderTextColor("black", 300);
                }

                TMG.Phone.Data.currentApplication = PressedApplication;

                if (PressedApplication == "settings") {
                    $("#myPhoneNumber").text(TMG.Phone.Data.PlayerData.charinfo.phone);
                    $("#mySerialNumber").text("TMG-" + TMG.Phone.Data.PlayerData.metadata["phonedata"].SerialNumber);
                } else if (PressedApplication == "twitter") {
                    $.post('https://tmg-phone/GetMentionedTweets', JSON.stringify({}), function(MentionedTweets){
                        TMG.Phone.Notifications.LoadMentionedTweets(MentionedTweets)
                    })
                    $.post('https://tmg-phone/GetHashtags', JSON.stringify({}), function(Hashtags){
                        TMG.Phone.Notifications.LoadHashtags(Hashtags)
                    })
                    if (TMG.Phone.Data.IsOpen) {
                        $.post('https://tmg-phone/GetTweets', JSON.stringify({}), function(Tweets){
                            TMG.Phone.Notifications.LoadTweets(Tweets);
                        });
                    }
                } else if (PressedApplication == "bank") {
                    TMG.Phone.Functions.DoBankOpen();
                    $.post('https://tmg-phone/GetBankContacts', JSON.stringify({}), function(contacts){
                        TMG.Phone.Functions.LoadContactsWithNumber(contacts);
                    });
                    $.post('https://tmg-phone/GetInvoices', JSON.stringify({}), function(invoices){
                        TMG.Phone.Functions.LoadBankInvoices(invoices);
                    });
                } else if (PressedApplication == "whatsapp") {
                    $.post('https://tmg-phone/GetWhatsappChats', JSON.stringify({}), function(chats){
                        TMG.Phone.Functions.LoadWhatsappChats(chats);
                    });
                } else if (PressedApplication == "phone") {
                    $.post('https://tmg-phone/GetMissedCalls', JSON.stringify({}), function(recent){
                        TMG.Phone.Functions.SetupRecentCalls(recent);
                    });
                    $.post('https://tmg-phone/GetSuggestedContacts', JSON.stringify({}), function(suggested){
                        TMG.Phone.Functions.SetupSuggestedContacts(suggested);
                    });
                    $.post('https://tmg-phone/ClearGeneralAlerts', JSON.stringify({
                        app: "phone"
                    }));
                } else if (PressedApplication == "mail") {
                    $.post('https://tmg-phone/GetMails', JSON.stringify({}), function(mails){
                        TMG.Phone.Functions.SetupMails(mails);
                    });
                    $.post('https://tmg-phone/ClearGeneralAlerts', JSON.stringify({
                        app: "mail"
                    }));
                } else if (PressedApplication == "advert") {
                    $.post('https://tmg-phone/LoadAdverts', JSON.stringify({}), function(Adverts){
                        TMG.Phone.Functions.RefreshAdverts(Adverts);
                    })
                } else if (PressedApplication == "garage") {
                    $.post('https://tmg-phone/SetupGarageVehicles', JSON.stringify({}), function(Vehicles){
                        SetupGarageVehicles(Vehicles);
                    })
                } else if (PressedApplication == "crypto") {
                    $.post('https://tmg-phone/GetCryptoData', JSON.stringify({
                        crypto: "qbit",
                    }), function(CryptoData){
                        SetupCryptoData(CryptoData);
                    })

                    $.post('https://tmg-phone/GetCryptoTransactions', JSON.stringify({}), function(data){
                        RefreshCryptoTransactions(data);
                    })
                } else if (PressedApplication == "racing") {
                    $.post('https://tmg-phone/GetAvailableRaces', JSON.stringify({}), function(Races){
                        SetupRaces(Races);
                    });
                } else if (PressedApplication == "houses") {
                    $.post('https://tmg-phone/GetPlayerHouses', JSON.stringify({}), function(Houses){
                        SetupPlayerHouses(Houses);
                    });
                    $.post('https://tmg-phone/GetPlayerKeys', JSON.stringify({}), function(Keys){
                        $(".house-app-mykeys-container").html("");
                        if (Keys.length > 0) {
                            $.each(Keys, function(i, key){
                                var elem = '<div class="mykeys-key" id="keyid-'+i+'"><span class="mykeys-key-label">' + key.HouseData.adress + '</span> <span class="mykeys-key-sub">Click to set GPS</span> </div>';
                                $(".house-app-mykeys-container").append(elem);
                                $("#keyid-"+i).data('KeyData', key);
                            });
                        }
                    });
                } else if (PressedApplication == "meos") {
                    SetupMeosHome();
                } else if (PressedApplication == "lawyers") {
                    $.post('https://tmg-phone/GetCurrentLawyers', JSON.stringify({}), function(data){
                        SetupLawyers(data);
                    });
                } else if (PressedApplication == "store") {
                    $.post('https://tmg-phone/SetupStoreApps', JSON.stringify({}), function(data){
                        SetupAppstore(data);
                    });
                } else if (PressedApplication == "trucker") {
                    $.post('https://tmg-phone/GetTruckerData', JSON.stringify({}), function(data){
                        SetupTruckerInfo(data);
                    });
                }
                else if (PressedApplication == "gallery") {
                    $.post('https://tmg-phone/GetGalleryData', JSON.stringify({}), function(data){
                        setUpGalleryData(data);
                    });
                }
                else if (PressedApplication == "camera") {
                    $.post('https://tmg-phone/TakePhoto', JSON.stringify({}),function(url){
                        setUpCameraApp(url)
                    })
                    TMG.Phone.Functions.Close();
                }

                
            }
        }
    } else {
        if (PressedApplication != null){
            TMG.Phone.Notifications.Add("fas fa-exclamation-circle", "System", TMG.Phone.Data.Applications[PressedApplication].tooltipText+" is not available!")
        }
    }
});

$(document).on('click', '.mykeys-key', function(e){
    e.preventDefault();

    var KeyData = $(this).data('KeyData');

    $.post('https://tmg-phone/SetHouseLocation', JSON.stringify({
        HouseData: KeyData
    }))
});

$(document).on('click', '.phone-home-container', function(event){
    event.preventDefault();

    if (TMG.Phone.Data.currentApplication === null) {
        TMG.Phone.Functions.Close();
    } else {
        TMG.Phone.Animations.TopSlideUp('.phone-application-container', 400, -160);
        TMG.Phone.Animations.TopSlideUp('.'+TMG.Phone.Data.currentApplication+"-app", 400, -160);
        CanOpenApp = false;
        setTimeout(function(){
            TMG.Phone.Functions.ToggleApp(TMG.Phone.Data.currentApplication, "none");
            CanOpenApp = true;
        }, 400)
        TMG.Phone.Functions.HeaderTextColor("white", 300);

        if (TMG.Phone.Data.currentApplication == "whatsapp") {
            if (OpenedChatData.number !== null) {
                setTimeout(function(){
                    $(".whatsapp-chats").css({"display":"block"});
                    $(".whatsapp-chats").animate({
                        left: 0+"vh"
                    }, 1);
                    $(".whatsapp-openedchat").animate({
                        left: -30+"vh"
                    }, 1, function(){
                        $(".whatsapp-openedchat").css({"display":"none"});
                    });
                    OpenedChatPicture = null;
                    OpenedChatData.number = null;
                }, 450);
            }
        } else if (TMG.Phone.Data.currentApplication == "bank") {
            if (CurrentTab == "invoices") {
                setTimeout(function(){
                    $(".bank-app-invoices").animate({"left": "30vh"});
                    $(".bank-app-invoices").css({"display":"none"})
                    $(".bank-app-accounts").css({"display":"block"})
                    $(".bank-app-accounts").css({"left": "0vh"});

                    var InvoicesObjectBank = $(".bank-app-header").find('[data-headertype="invoices"]');
                    var HomeObjectBank = $(".bank-app-header").find('[data-headertype="accounts"]');

                    $(InvoicesObjectBank).removeClass('bank-app-header-button-selected');
                    $(HomeObjectBank).addClass('bank-app-header-button-selected');

                    CurrentTab = "accounts";
                }, 400)
            }
        } else if (TMG.Phone.Data.currentApplication == "meos") {
            $(".meos-alert-new").remove();
            setTimeout(function(){
                $(".meos-recent-alert").removeClass("noodknop");
                $(".meos-recent-alert").css({"background-color":"#004682"});
            }, 400)
        }

        TMG.Phone.Data.currentApplication = null;
    }
});

TMG.Phone.Functions.Open = function(data) {
    TMG.Phone.Animations.BottomSlideUp('.container', 300, 0);
    TMG.Phone.Notifications.LoadTweets(data.Tweets);
    TMG.Phone.Data.IsOpen = true;
}

TMG.Phone.Functions.ToggleApp = function(app, show) {
    $("."+app+"-app").css({"display":show});
}

TMG.Phone.Functions.Close = function() {

    if (TMG.Phone.Data.currentApplication == "whatsapp") {
        setTimeout(function(){
            TMG.Phone.Animations.TopSlideUp('.phone-application-container', 400, -160);
            TMG.Phone.Animations.TopSlideUp('.'+TMG.Phone.Data.currentApplication+"-app", 400, -160);
            $(".whatsapp-app").css({"display":"none"});
            TMG.Phone.Functions.HeaderTextColor("white", 300);

            if (OpenedChatData.number !== null) {
                setTimeout(function(){
                    $(".whatsapp-chats").css({"display":"block"});
                    $(".whatsapp-chats").animate({
                        left: 0+"vh"
                    }, 1);
                    $(".whatsapp-openedchat").animate({
                        left: -30+"vh"
                    }, 1, function(){
                        $(".whatsapp-openedchat").css({"display":"none"});
                    });
                    OpenedChatData.number = null;
                }, 450);
            }
            OpenedChatPicture = null;
            TMG.Phone.Data.currentApplication = null;
        }, 500)
    } else if (TMG.Phone.Data.currentApplication == "meos") {
        $(".meos-alert-new").remove();
        $(".meos-recent-alert").removeClass("noodknop");
        $(".meos-recent-alert").css({"background-color":"#004682"});
    }

    TMG.Phone.Animations.BottomSlideDown('.container', 300, -70);
    $.post('https://tmg-phone/Close');
    TMG.Phone.Data.IsOpen = false;
}

TMG.Phone.Functions.HeaderTextColor = function(newColor, Timeout) {
    $(".phone-header").animate({color: newColor}, Timeout);
}

TMG.Phone.Animations.BottomSlideUp = function(Object, Timeout, Percentage) {
    $(Object).css({'display':'block'}).animate({
        bottom: Percentage+"%",
    }, Timeout);
}

TMG.Phone.Animations.BottomSlideDown = function(Object, Timeout, Percentage) {
    $(Object).css({'display':'block'}).animate({
        bottom: Percentage+"%",
    }, Timeout, function(){
        $(Object).css({'display':'none'});
    });
}

TMG.Phone.Animations.TopSlideDown = function(Object, Timeout, Percentage) {
    $(Object).css({'display':'block'}).animate({
        top: Percentage+"%",
    }, Timeout);
}

TMG.Phone.Animations.TopSlideUp = function(Object, Timeout, Percentage, cb) {
    $(Object).css({'display':'block'}).animate({
        top: Percentage+"%",
    }, Timeout, function(){
        $(Object).css({'display':'none'});
    });
}

TMG.Phone.Notifications.Add = function(icon, title, text, color, timeout) {
    $.post('https://tmg-phone/HasPhone', JSON.stringify({}), function(HasPhone){
        if (HasPhone) {
            if (timeout == null && timeout == undefined) {
                timeout = 1500;
            }
            if (TMG.Phone.Notifications.Timeout == undefined || TMG.Phone.Notifications.Timeout == null) {
                if (color != null || color != undefined) {
                    $(".notification-icon").css({"color":color});
                    $(".notification-title").css({"color":color});
                } else if (color == "default" || color == null || color == undefined) {
                    $(".notification-icon").css({"color":"#e74c3c"});
                    $(".notification-title").css({"color":"#e74c3c"});
                }
                if (!TMG.Phone.Data.IsOpen) {
                    TMG.Phone.Animations.BottomSlideUp('.container', 300, -52);
                }
                TMG.Phone.Animations.TopSlideDown(".phone-notification-container", 200, 8);
                if (icon !== "politie") {
                    $(".notification-icon").html('<i class="'+icon+'"></i>');
                } else {
                    $(".notification-icon").html('<img src="./img/politie.png" class="police-icon-notify">');
                }
                $(".notification-title").html(title);
                $(".notification-text").html(text);
                if (TMG.Phone.Notifications.Timeout !== undefined || TMG.Phone.Notifications.Timeout !== null) {
                    clearTimeout(TMG.Phone.Notifications.Timeout);
                }
                TMG.Phone.Notifications.Timeout = setTimeout(function(){
                    TMG.Phone.Animations.TopSlideUp(".phone-notification-container", 200, -8);
                    if (!TMG.Phone.Data.IsOpen) {
                        TMG.Phone.Animations.BottomSlideUp('.container', 300, -100);
                    }
                    TMG.Phone.Notifications.Timeout = null;
                }, timeout);
            } else {
                if (color != null || color != undefined) {
                    $(".notification-icon").css({"color":color});
                    $(".notification-title").css({"color":color});
                } else {
                    $(".notification-icon").css({"color":"#e74c3c"});
                    $(".notification-title").css({"color":"#e74c3c"});
                }
                if (!TMG.Phone.Data.IsOpen) {
                    TMG.Phone.Animations.BottomSlideUp('.container', 300, -52);
                }
                $(".notification-icon").html('<i class="'+icon+'"></i>');
                $(".notification-title").html(title);
                $(".notification-text").html(text);
                if (TMG.Phone.Notifications.Timeout !== undefined || TMG.Phone.Notifications.Timeout !== null) {
                    clearTimeout(TMG.Phone.Notifications.Timeout);
                }
                TMG.Phone.Notifications.Timeout = setTimeout(function(){
                    TMG.Phone.Animations.TopSlideUp(".phone-notification-container", 200, -8);
                    if (!TMG.Phone.Data.IsOpen) {
                        TMG.Phone.Animations.BottomSlideUp('.container', 300, -100);
                    }
                    TMG.Phone.Notifications.Timeout = null;
                }, timeout);
            }
        }
    });
}

TMG.Phone.Functions.LoadPhoneData = function(data) {
    TMG.Phone.Data.PlayerData = data.PlayerData;
    TMG.Phone.Data.PlayerJob = data.PlayerJob;
    TMG.Phone.Data.MetaData = data.PhoneData.MetaData;
    TMG.Phone.Functions.LoadMetaData(data.PhoneData.MetaData);
    TMG.Phone.Functions.LoadContacts(data.PhoneData.Contacts);
    TMG.Phone.Functions.SetupApplications(data);

    $("#player-id").html("<span>" + "ID: " + data.PlayerId + "</span>")
}

TMG.Phone.Functions.UpdateTime = function(data) {
    var NewDate = new Date();
    var NewHour = NewDate.getHours();
    var NewMinute = NewDate.getMinutes();
    var Minutessss = NewMinute;
    var Hourssssss = NewHour;
    if (NewHour < 10) {
        Hourssssss = "0" + Hourssssss;
    }
    if (NewMinute < 10) {
        Minutessss = "0" + NewMinute;
    }
    var MessageTime = Hourssssss + ":" + Minutessss

    $("#phone-time").html("<span>" + data.InGameTime.hour + ":" + data.InGameTime.minute + "</span>");
}

var NotificationTimeout = null;

TMG.Screen.Notification = function(title, content, icon, timeout, color) {
    $.post('https://tmg-phone/HasPhone', JSON.stringify({}), function(HasPhone){
        if (HasPhone) {
            if (color != null && color != undefined) {
                $(".screen-notifications-container").css({"background-color":color});
            }
            $(".screen-notification-icon").html('<i class="'+icon+'"></i>');
            $(".screen-notification-title").text(title);
            $(".screen-notification-content").text(content);
            $(".screen-notifications-container").css({'display':'block'}).animate({
                right: 5+"vh",
            }, 200);

            if (NotificationTimeout != null) {
                clearTimeout(NotificationTimeout);
            }

            NotificationTimeout = setTimeout(function(){
                $(".screen-notifications-container").animate({
                    right: -35+"vh",
                }, 200, function(){
                    $(".screen-notifications-container").css({'display':'none'});
                });
                NotificationTimeout = null;
            }, timeout);
        }
    });
}

$(document).on('keydown', function() {
    switch(event.keyCode) {
        case 27: // ESCAPE
        if (up){
            $('#popup').fadeOut('slow');
            $('.popupclass').fadeOut('slow');
            $('.popupclass').html("");
            up = false
        } else {
            TMG.Phone.Functions.Close();
            break;
        }
    }
});

TMG.Screen.popUp = function(source){
    if(!up){
        $('#popup').fadeIn('slow');
        $('.popupclass').fadeIn('slow');
        $('<img  src='+source+' style = "width:100%; height: 100%;">').appendTo('.popupclass')
        up = true
    }
}

TMG.Screen.popDown = function(){
    if(up){
        $('#popup').fadeOut('slow');
        $('.popupclass').fadeOut('slow');
        $('.popupclass').html("");
        up = false
    }
}

$(document).ready(function(){
    window.addEventListener('message', function(event) {
        switch(event.data.action) {
            case "open":
                TMG.Phone.Functions.Open(event.data);
                TMG.Phone.Functions.SetupAppWarnings(event.data.AppData);
                TMG.Phone.Functions.SetupCurrentCall(event.data.CallData);
                TMG.Phone.Data.IsOpen = true;
                TMG.Phone.Data.PlayerData = event.data.PlayerData;
                break;
            case "LoadPhoneData":
                TMG.Phone.Functions.LoadPhoneData(event.data);
                break;
            case "UpdateTime":
                TMG.Phone.Functions.UpdateTime(event.data);
                break;
            case "Notification":
                TMG.Screen.Notification(event.data.NotifyData.title, event.data.NotifyData.content, event.data.NotifyData.icon, event.data.NotifyData.timeout, event.data.NotifyData.color);
                break;
            case "PhoneNotification":
                TMG.Phone.Notifications.Add(event.data.PhoneNotify.icon, event.data.PhoneNotify.title, event.data.PhoneNotify.text, event.data.PhoneNotify.color, event.data.PhoneNotify.timeout);
                break;
            case "RefreshAppAlerts":
                TMG.Phone.Functions.SetupAppWarnings(event.data.AppData);
                break;
            case "UpdateMentionedTweets":
                TMG.Phone.Notifications.LoadMentionedTweets(event.data.Tweets);
                break;
            case "UpdateBank":
                $(".bank-app-account-balance").html("&#36; "+event.data.NewBalance);
                $(".bank-app-account-balance").data('balance', event.data.NewBalance);
                break;
            case "UpdateChat":
                if (TMG.Phone.Data.currentApplication == "whatsapp") {
                    if (OpenedChatData.number !== null && OpenedChatData.number == event.data.chatNumber) {
                        TMG.Phone.Functions.SetupChatMessages(event.data.chatData);
                    } else {
                        TMG.Phone.Functions.LoadWhatsappChats(event.data.Chats);
                    }
                }
                break;
            case "UpdateHashtags":
                TMG.Phone.Notifications.LoadHashtags(event.data.Hashtags);
                break;
            case "RefreshWhatsappAlerts":
                TMG.Phone.Functions.ReloadWhatsappAlerts(event.data.Chats);
                break;
            case "CancelOutgoingCall":
                $.post('https://tmg-phone/HasPhone', JSON.stringify({}), function(HasPhone){
                    if (HasPhone) {
                        CancelOutgoingCall();
                    }
                });
                break;
            case "IncomingCallAlert":
                $.post('https://tmg-phone/HasPhone', JSON.stringify({}), function(HasPhone){
                    if (HasPhone) {
                        IncomingCallAlert(event.data.CallData, event.data.Canceled, event.data.AnonymousCall);
                    }
                });
                break;
            case "SetupHomeCall":
                TMG.Phone.Functions.SetupCurrentCall(event.data.CallData);
                break;
            case "AnswerCall":
                TMG.Phone.Functions.AnswerCall(event.data.CallData);
                break;
            case "UpdateCallTime":
                var CallTime = event.data.Time;
                var date = new Date(null);
                date.setSeconds(CallTime);
                var timeString = date.toISOString().substr(11, 8);
                if (!TMG.Phone.Data.IsOpen) {
                    if ($(".call-notifications").css("right") !== "52.1px") {
                        $(".call-notifications").css({"display":"block"});
                        $(".call-notifications").animate({right: 5+"vh"});
                    }
                    $(".call-notifications-title").html("In conversation ("+timeString+")");
                    $(".call-notifications-content").html("Calling with "+event.data.Name);
                    $(".call-notifications").removeClass('call-notifications-shake');
                } else {
                    $(".call-notifications").animate({
                        right: -35+"vh"
                    }, 400, function(){
                        $(".call-notifications").css({"display":"none"});
                    });
                }
                $(".phone-call-ongoing-time").html(timeString);
                $(".phone-currentcall-title").html("In conversation ("+timeString+")");
                break;
            case "CancelOngoingCall":
                $(".call-notifications").animate({right: -35+"vh"}, function(){
                    $(".call-notifications").css({"display":"none"});
                });
                TMG.Phone.Animations.TopSlideUp('.phone-application-container', 400, -160);
                setTimeout(function(){
                    TMG.Phone.Functions.ToggleApp("phone-call", "none");
                    $(".phone-application-container").css({"display":"none"});
                }, 400)
                TMG.Phone.Functions.HeaderTextColor("white", 300);

                TMG.Phone.Data.CallActive = false;
                TMG.Phone.Data.currentApplication = null;
                break;
            case "RefreshContacts":
                TMG.Phone.Functions.LoadContacts(event.data.Contacts);
                break;
            case "UpdateMails":
                TMG.Phone.Functions.SetupMails(event.data.Mails);
                break;
            case "RefreshAdverts":
                if (TMG.Phone.Data.currentApplication == "advert") {
                    TMG.Phone.Functions.RefreshAdverts(event.data.Adverts);
                }
                break;
            case "UpdateTweets":
                if (TMG.Phone.Data.currentApplication == "twitter") {
                    TMG.Phone.Notifications.LoadTweets(event.data.Tweets);
                }
                break;
            case "AddPoliceAlert":
                AddPoliceAlert(event.data)
                break;
            case "UpdateApplications":
                TMG.Phone.Data.PlayerJob = event.data.JobData;
                TMG.Phone.Functions.SetupApplications(event.data);
                break;
            case "UpdateTransactions":
                RefreshCryptoTransactions(event.data);
                break;
            case "UpdateRacingApp":
                $.post('https://tmg-phone/GetAvailableRaces', JSON.stringify({}), function(Races){
                    SetupRaces(Races);
                });
                break;
            case "RefreshAlerts":
                TMG.Phone.Functions.SetupAppWarnings(event.data.AppData);
                break;
        }
    })
});