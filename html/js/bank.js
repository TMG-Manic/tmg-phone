var FoccusedBank = null;

$(document).on('click', '.bank-app-account', function(e){
    var copyText = document.getElementById("iban-account");
    copyText.select();
    copyText.setSelectionRange(0, 99999);
    document.execCommand("copy");

    TMG.Phone.Notifications.Add("fas fa-university", "TMGank", "Account number. copied!", "#badc58", 1750);
});

var CurrentTab = "accounts";

$(document).on('click', '.bank-app-header-button', function(e){
    e.preventDefault();

    var PressedObject = this;
    var PressedTab = $(PressedObject).data('headertype');

    if (CurrentTab != PressedTab) {
        var PreviousObject = $(".bank-app-header").find('[data-headertype="'+CurrentTab+'"]');

        if (PressedTab == "invoices") {
            $(".bank-app-"+CurrentTab).animate({
                left: -30+"vh"
            }, 250, function(){
                $(".bank-app-"+CurrentTab).css({"display":"none"})
            });
            $(".bank-app-"+PressedTab).css({"display":"block"}).animate({
                left: 0+"vh"
            }, 250);
        } else if (PressedTab == "accounts") {
            $(".bank-app-"+CurrentTab).animate({
                left: 30+"vh"
            }, 250, function(){
                $(".bank-app-"+CurrentTab).css({"display":"none"})
            });
            $(".bank-app-"+PressedTab).css({"display":"block"}).animate({
                left: 0+"vh"
            }, 250);
        }

        $(PreviousObject).removeClass('bank-app-header-button-selected');
        $(PressedObject).addClass('bank-app-header-button-selected');
        setTimeout(function(){ CurrentTab = PressedTab; }, 300)
    }
})

TMG.Phone.Functions.DoBankOpen = function() {
    TMG.Phone.Data.PlayerData.money.bank = (TMG.Phone.Data.PlayerData.money.bank).toFixed();
    $(".bank-app-account-number").val(TMG.Phone.Data.PlayerData.charinfo.account);
    $(".bank-app-account-balance").html("&#36; "+TMG.Phone.Data.PlayerData.money.bank);
    $(".bank-app-account-balance").data('balance', TMG.Phone.Data.PlayerData.money.bank);

    $(".bank-app-loaded").css({"display":"none", "padding-left":"30vh"});
    $(".bank-app-accounts").css({"left":"30vh"});
    $(".qbank-logo").css({"left": "0vh"});
    $("#qbank-text").css({"opacity":"0.0", "left":"9vh"});
    $(".bank-app-loading").css({
        "display":"block",
        "left":"0vh",
    });
    setTimeout(function(){
        CurrentTab = "accounts";
        $(".qbank-logo").animate({
            left: -12+"vh"
        }, 500);
        setTimeout(function(){
            $("#qbank-text").animate({
                opacity: 1.0,
                left: 14+"vh"
            });
        }, 100);
        setTimeout(function(){
            $(".bank-app-loaded").css({"display":"block"}).animate({"padding-left":"0"}, 300);
            $(".bank-app-accounts").animate({left:0+"vh"}, 300);
            $(".bank-app-loading").animate({
                left: -30+"vh"
            },300, function(){
                $(".bank-app-loading").css({"display":"none"});
            });
        }, 1500)
    }, 500)
}

$(document).on('click', '.bank-app-account-actions', function(e){
    TMG.Phone.Animations.TopSlideDown(".bank-app-transfer", 400, 0);
});

$(document).on('click', '#cancel-transfer', function(e){
    e.preventDefault();

    TMG.Phone.Animations.TopSlideUp(".bank-app-transfer", 400, -100);
});

$(document).on('click', '#accept-transfer', function(e){
    e.preventDefault();

    var iban = $("#bank-transfer-iban").val();
    var amount = $("#bank-transfer-amount").val();
    var amountData = $(".bank-app-account-balance").data('balance');

    if (iban != "" && amount != "") {
            $.post('https://tmg-phone/CanTransferMoney', JSON.stringify({
                sendTo: iban,
                amountOf: amount,
            }), function(data){
                if (data.TransferedMoney) {
                    $("#bank-transfer-iban").val("");
                    $("#bank-transfer-amount").val("");

                    $(".bank-app-account-balance").html("&#36; " + (data.NewBalance).toFixed(0));
                    $(".bank-app-account-balance").data('balance', (data.NewBalance).toFixed(0));
                    TMG.Phone.Notifications.Add("fas fa-university", "TMGank", "You have transfered &#36; "+amount+"!", "#badc58", 1500);
                } else {
                    TMG.Phone.Notifications.Add("fas fa-university", "TMGank", "You don't have enough balance!", "#badc58", 1500);
                }
                TMG.Phone.Animations.TopSlideUp(".bank-app-transfer", 400, -100);
            });
    } else {
        TMG.Phone.Notifications.Add("fas fa-university", "TMGank", "Fill out all fields!", "#badc58", 1750);
    }
});

GetInvoiceLabel = function(type) {
    retval = null;
    if (type == "request") {
        retval = "Payment Request";
    }

    return retval
}

$(document).on('click', '.pay-invoice', function(event){
    event.preventDefault();

    var InvoiceId = $(this).parent().parent().parent().attr('id');
    var InvoiceData = $("#"+InvoiceId).data('invoicedata');
    var BankBalance = $(".bank-app-account-balance").data('balance');

    if (BankBalance >= InvoiceData.amount) {
        $.post('https://tmg-phone/PayInvoice', JSON.stringify({
            sender: InvoiceData.sender,
            amount: InvoiceData.amount,
            society: InvoiceData.society,
            invoiceId: InvoiceData.id,
            senderCitizenId: InvoiceData.sendercitizenid
        }), function(CanPay){
            if (CanPay) {
                $("#"+InvoiceId).animate({
                    left: 30+"vh",
                }, 300, function(){
                    setTimeout(function(){
                        $("#"+InvoiceId).remove();
                    }, 100);
                });
                TMG.Phone.Notifications.Add("fas fa-university", "TMGank", "You have paid &#36;"+InvoiceData.amount+"!", "#badc58", 1500);
                var amountData = $(".bank-app-account-balance").data('balance');
                var NewAmount = (amountData - InvoiceData.amount).toFixed();
                $("#bank-transfer-amount").val(NewAmount);
                $(".bank-app-account-balance").data('balance', NewAmount);
            } else {
                TMG.Phone.Notifications.Add("fas fa-university", "TMGank", "You don't have enough balance!", "#badc58", 1500);
            }
        });
    } else {
        TMG.Phone.Notifications.Add("fas fa-university", "TMGank", "You don't have enough balance!", "#badc58", 1500);
    }
});

$(document).on('click', '.decline-invoice', async function(event) {
    event.preventDefault();
    var InvoiceId = $(this).parent().parent().parent().attr('id');
    var InvoiceData = $("#"+InvoiceId).data('invoicedata');

    const resp = await $.post('https://tmg-phone/DeclineInvoice', JSON.stringify({
        sender: InvoiceData.sender,
        amount: InvoiceData.amount,
        society: InvoiceData.society,
        invoiceId: InvoiceData.id,
    }));
    if(resp === true) {
        TMG.Phone.Notifications.Add("fas fa-university", "TMGank", "You declined the invoice", "#8c7ae6")
        $("#"+InvoiceId).animate({
            left: 30+"vh",
        }, 300, function(){
            setTimeout(function(){
                $("#"+InvoiceId).remove();
            }, 100);
        });
    } else {
        TMG.Phone.Notifications.Add("fas fa-university", "TMGank", "Couldnt decline this invoice...", "#8c7ae6")
    }
});

TMG.Phone.Functions.LoadBankInvoices = function(invoices) {
    if (invoices !== null && invoices !== undefined) {
        $(".bank-app-invoices-list").html("");
        $.each(invoices, function(i, invoice) {
            var invId = invoice.invoiceId || invoice.id;
            var senderCid = invoice.sendercitizenid || invoice.senderCitizenId || invoice.sender;
            
            var Elem = '<div class="bank-app-invoice" id="invoiceid-' + invId + '"> <div class="bank-app-invoice-title">' + invoice.society + ' <span style="font-size: 1vh; color: gray;">(Sender: ' + invoice.sender + ')</span></div>' + (typeof invoice.reason === 'string' ? `<div class="bank-app-invoice-reason">${invoice.reason}</div>` : '') + '<div class="bank-app-invoice-info"><div class="bank-app-invoice-amount">&#36; ' + invoice.amount + '</div> <div class="bank-app-invoice-buttons"> <i class="fas fa-check-circle pay-invoice"></i>' + (invoice.candecline === 1 ? '<i class="fas fa-times-circle decline-invoice"></i>' : '') + '</div></div></div>';
            
            $(".bank-app-invoices-list").append(Elem);
            
            // Standardize object data key so PayInvoice/DeclineInvoice click handlers read the safe ID
            invoice.invoiceId = invId;
            invoice.senderCitizenId = senderCid;
            $("#invoiceid-" + invId).data('invoicedata', invoice);
        });
    }
};

TMG.Phone.Functions.LoadContactsWithNumber = function(myContacts) {
    var ContactsObject = $(".bank-app-my-contacts-list");
    $(ContactsObject).html("");
    var TotalContacts = 0;

    $("#bank-app-my-contact-search").on("keyup", function() {
        var value = $(this).val().toLowerCase();
        $(".bank-app-my-contacts-list .bank-app-my-contact").filter(function() {
          $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1);
        });
    });

    if (myContacts !== null) {
        $.each(myContacts, function(i, contact){
            var RandomNumber = Math.floor(Math.random() * 6);
            var ContactColor = TMG.Phone.ContactColors[RandomNumber];
            var ContactElement = '<div class="bank-app-my-contact" data-bankcontactid="'+i+'"> <div class="bank-app-my-contact-firstletter">'+((contact.name).charAt(0)).toUpperCase()+'</div> <div class="bank-app-my-contact-name">'+contact.name+'</div> </div>'
            TotalContacts = TotalContacts + 1
            $(ContactsObject).append(ContactElement);
            $("[data-bankcontactid='"+i+"']").data('contactData', contact);
        });
    }
};

$(document).on('click', '.bank-app-my-contacts-list-back', function(e){
    e.preventDefault();

    TMG.Phone.Animations.TopSlideUp(".bank-app-my-contacts", 400, -100);
});

$(document).on('click', '.bank-transfer-mycontacts-icon', function(e){
    e.preventDefault();

    TMG.Phone.Animations.TopSlideDown(".bank-app-my-contacts", 400, 0);
});

$(document).on('click', '.bank-app-my-contact', function(e){
    e.preventDefault();
    var PressedContactData = $(this).data('contactData');

    if (PressedContactData.iban !== "" && PressedContactData.iban !== undefined && PressedContactData.iban !== null) {
        $("#bank-transfer-iban").val(PressedContactData.iban);
    } else {
        TMG.Phone.Notifications.Add("fas fa-university", "TMGank", "There is no bank account attached to this number!", "#badc58", 2500);
    }
    TMG.Phone.Animations.TopSlideUp(".bank-app-my-contacts", 400, -100);
});