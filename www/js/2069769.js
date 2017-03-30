// 2069769.js "gab central javascript"
// Probably powers [gab central]

function replyTo(f, s, c) {
       if (c || document.forms[f].setvar_autofillInbox.checked) {
          document.forms[f].message.value = "/msg "+s+" ";
          document.forms[f].message.focus();
       }
}

function replyToEddie (s) {
       replyTo(2,s,1);
}

function clearReply(f) {
	document.forms[f].message.value = "";
}

function checkAll(f){
    for (i=0; i < document.forms[f].elements.length; i++) {
      if(document.forms[f].elements[i].name.substring(0,9) == "deletemsg")
          {document.forms[f].elements[i].checked=true;}
    }
}
