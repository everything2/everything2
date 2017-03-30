// 2069795.js - Message inbox javascript
// Probably used in [Message Inbox]

function replyTo(s, c) {
       if (c || document.message_inbox_form.setvar_autofillInbox.checked) {
          document.message_inbox_form.message.value = "/msg "+s+" ";
          document.message_inbox_form.message.focus();
       }
}

function replyToEddie (s) {
       replyTo(s,1);
}

function clearReply() {
	document.message_inbox_form.message.value = "";
}

function checkAll(){
    for (i=0; i < document.message_inbox_form.elements.length; i++) {
      if(document.message_inbox_form.elements[i].name.substring(0,9) == "deletemsg")
          {document.message_inbox_form.elements[i].checked=true;}
    }
}


function archiveAll() {
    for (i=0; i < document.message_inbox_form.elements.length; i++) {
      if(document.message_inbox_form.elements[i].name.substring(0,7) == "archive")
          {document.message_inbox_form.elements[i].checked=true;}
    }
}

function unarchiveAll() {
    for (i=0; i < document.message_inbox_form.elements.length; i++) {
      if(document.message_inbox_form.elements[i].name.substring(0,9) == "unarchive")
          {document.message_inbox_form.elements[i].checked=true;}
    }
}

function clearArchive() {
    for (i=0; i < document.message_inbox_form.elements.length; i++) {
      if((document.message_inbox_form.elements[i].name.substring(0,7) == "archive") || (document.message_inbox_form.elements[i].name.substring(0,9) == "unarchive"))
          {document.message_inbox_form.elements[i].checked=false;}
    }
}

function enlargeTextbox(textbox) {
   if (textbox.morph) {
      textbox.morph('height: 15em;');
   }
   else {
      textbox.style.height = '15em';
      textbox.rows = 8;
   }
}

function shrinkTextbox(textbox) {
   // Only shrink box back down if no text has been entered
   if (textbox.value === "") {

      if (textbox.morph) {
         textbox.morph('height: 2em;');
      }
      else {
         // Don't do jarring shrinking effect if morphing is not enabled
      }

   }

}
