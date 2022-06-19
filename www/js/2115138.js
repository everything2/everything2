// 2115138.js "jstest"
// Used in [My Chatterlight]

function InDebugMode(){
   return window.location.href.indexOf("debug")>0;
}

// General vars
var contentRefreshInterval = null;
var statusId = 0;

// Chatterbox vars
var chat_RefreshTime = 10000;   // in milliseconds (1000ms = 1s, 10000ms = 10s)
var chat_MsgLimit = 0;
var chat_MsgTime = new Date(2000, 1, 1);  // just a date in the past, the actual value doesn't matter
var chat_LastMessage = new Date();
var chat_NextSilenceNotification = 60000;
var chat_SilenceNotificationInterval = 60000;
var chat_IsFirstLoad = true;
var chat_GravatarSize = 32;
var chat_EggCommands = {
   anvil:         'anvils',
   blame:         'blames',
   egg:           'eggs',
   fireball:      'casts fireball on',
   giantsquid:    'giant squids',
   highfive:      'highfives',
   hug:           'hugs',
   hugg:          'mis-spells',
   immolate:      'casts fireball on',
   maul:          'mauls',
   omelet:        'omelets',
   omelette:      'French-omelets',
   pie:           'pies',
   pizza:         'pizzas',
   rubberchicken: 'rubber chickens',
   smite:         'smites',
   special:       "does something 'special' to",
   tea:           'makes a nice cup of tea for',
   tomato:        'tomatoes'
};

// Message Inbox vars
var mi_RefreshTime = 60000;    // in milliseconds (1000ms = 1s, 60000ms = 1min)
var mi_MsgLimit = 0;
var mi_IsFirstLoad = true;
var mi_Backtime = 1440;        // in minutes (1440min = 1day)
var mi_GravatarSize = 32;

// Other Users vars
var ou_RefreshTime = 60000;    // in milliseconds
var ou_IsFirstLoad = true;
var ou_GravatarSize = 22;

function RefreshMessageInbox(){
   $.ajax({
      type: 'GET',
      url: '/index.pl?node=Universal Message XML Ticker&for_node=me&msglimit='+mi_MsgLimit+'&backtime='+mi_Backtime,
      dataType: 'xml',
      timeout: 25000,
      success: ParseMessageInbox
   });
}

function ParseMessageInbox(xml){
   if(InDebugMode()){
      // TODO
   }

   var msgCtr = 0;
   var author, group, html;
   $(xml).find("msg").each(function(){
      if($(this).attr('archive')!='1'){
         msgCtr++;
         mi_MsgLimit = $(this).attr('msg_id');
      
         author = $(this).find('from').find('e2link');
         group = $(this).find('grp').find('e2link');
      
         html = '<div class="Private clearfix" id="msg_'+mi_MsgLimit+'">';// +
         html+=   '<img src="http://hnimagew.everything2.com/' + GetClassName(author.text()) + '" alt="'+GetClassName(author.text())+'" align="left" height="'+mi_GravatarSize+'" width="'+mi_GravatarSize+'" />';// +
         html+=   '<p class="To">Private Message from <a href="/user/'+$.trim(author.text())+'">'+author.text()+'</a></b> to ';
         if(group.length==0){html += 'you';}
         else{html += '<a href="/node/usergroup/'+$.trim(group.text())+'">'+group.text()+'</a>';}
         html += ' ('+ParseE2Date($(this).attr('msg_time'))+')</p>' +
            '<p class="Text">'+$(this).find('txt').text()+'</p>' +
            '<ul>' +
            '<li><a href="#" onclick="Reply(\''+GetMsgUsername(author.text())+'\')">Reply to '+author.text()+'</a></li>';
         if(group.length>0){html += '<li><a href="#" onclick="Reply(\''+GetMsgUsername(group.text())+'\')">Reply to '+group.text()+'</a></li>';}
         html += '<li><a href="#" onclick="ArchiveMsg('+mi_MsgLimit+')">Archive</a></li>' +
            '<li><a href="#" onclick="DeleteMsg('+mi_MsgLimit+')">Delete</a></li>' +
            '</ul><div class="Clear"></div>' +
            '</div>';

         $('#Chatter').append(html);
      }
   });
   if(mi_IsFirstLoad&&msgCtr>0){
      ShowNotification('All of your private messages for the page 24 hours have been loaded above.');
   }
   ResizeChatArea(msgCtr>0);
   mi_IsFirstLoad = false;
}

function RefreshChatterbox(){
   var d = new Date();
   $.ajax({
      type: 'GET',
      url: '/index.pl?node=Universal Message XML Ticker&msglimit='+chat_MsgLimit+'&backtime=10&t='+d.getTime(),
      dataType: 'xml',
      timeout: 15000,
      success: ParseChatterbox
   });
}
function ParseChatterbox(xml){
   var uniqueId;
   // get topic
   var topic = $(xml).find('topic').text();
   /*
    * Why use the 'utility' area? When you take text (or HTML) and put it into the DOM, the 
    * browser may change the content as it sees fit (usually whitespace and
    * linebreaks, but it is not limited to that). Therefore comparing our
    * variable to the innerHTML of an existing DOM object might not match up even
    * if the topic has not changed. So we put our "new" topic into a hidden DOM
    * object, and compare the inner content of the two objects instead.
    */
   $('#utility').html(topic);
   // if the topic has changed, let the user know
   if ($('#utility').html() != $('#Topic').html()){
      if ($('#Topic').html() != ''){
         ShowNotification('The topic has changed.');
      }
      $('#Topic').html(topic);
   }

   var msgTime, minutes, author, newMsgLimit;
   var msgCtr = 0;

   /*
    * I found it extremely difficult to debug certain things while no one was talking,
    * this just adds some random text to the chatter on each reload.
    */
   if (InDebugMode()){
      var rndMsgId = GenerateUniqueId(10);
      $('#Chatter').append('<div class="msg" id="msg_'+rndMsgId+'">' + 
         '&lt;<a href="/user/'+rndMsgId+'" class="Author '+GetClassName(rndMsgId)+'">'+rndMsgId+'</a>&gt; ' +
         '<span class="Text">'+ParseMsgText(rndMsgId)+'</span>' +
         '</div>');
   }

   var html;
   $(xml).find("msg").each(function()
   {
      // set vars
      // It's possible that if a user force refresheds (or just "Talks"),
      // that we'll get duplicate messages, so we filter below based on the msg_id
      newMsgLimit = $(this).attr('msg_id');
      if (newMsgLimit > chat_MsgLimit){
         msgCtr++;
         html = ParsePublicMessage($(this));
         $('#Chatter').append(html);
      }
   });

   if (msgCtr==0 && chat_IsFirstLoad){
      ShowNotification('<b>You appear to be alone. No one has said anything for quite a while. Say something interesting, and maybe someone will respond...</b>');
   }
   var now = new Date();
   var silenceCount = now.getTime() - chat_LastMessage.getTime();
   if (silenceCount >= chat_NextSilenceNotification){
      chat_NextSilenceNotification += chat_SilenceNotificationInterval;
      ShowNotification('Nothing has been said in the last '+Math.floor(silenceCount/1000.0)+' seconds');
   }
   ResizeChatArea(msgCtr>0);
   chat_IsFirstLoad = false;
}

function ParsePublicMessage(msg){
   var html='';

   // msg time
   var prevMsgTime = chat_MsgTime;
   chat_LastMessage = new Date();
   nextSilenceNotification = chat_SilenceNotificationInterval;
   chat_MsgTime = ParseE2Date($(msg).attr('msg_time'));
   if(prevMsgTime.getMinutes() != chat_MsgTime.getMinutes() || prevMsgTime.getHours() != chat_MsgTime.getHours()){
      html += '<div class="dt">'+chat_MsgTime.getHours()+':'+Pad(chat_MsgTime.getMinutes(),2)+'</div>';
   }

   // Other Users helper
   var author = $(msg).find('from').find('e2link').text();
   if (!IsKnownUser(author)){
      InsertOtherUserUsername(author,true);
   }

   // msg   
   chat_MsgLimit = $(msg).attr('msg_id');
   var txt = $.trim($(msg).find('txt').text());
   var cssClass = 'Msg';
   var authorHtml = GetUserLink(author);
   // handle commands
   if(txt.indexOf('/')==0){
      // update cssClass and remove the command
      var spacePos = txt.indexOf(' ');
      var cmd = $.trim(txt.substring(1,spacePos).toLowerCase());
      cssClass += (' '+cmd);
      txt = $.trim(txt.substring(spacePos));
      if(chat_EggCommands[cmd]){
         txt = (chat_EggCommands[cmd]+' '+txt);
      }
   }else{
      authorHtml = '&lt;'+authorHtml+'&gt;';
   }
// gravatar src = "http://gravatar.com/avatar/'+$(msg).find('from').find('e2link').attr('md5')+'?d='+$('#gravatarType').val()+'&s=22"
   html += ('<div class="'+cssClass+' clearfix" id="'+$(msg).attr('msg_id')+'">' +
      '<img src="http://hnimagew.everything2.com/' + GetClassName(author) + '" alt="'+EncodeHtml(author)+'" height="'+chat_GravatarSize+'" width="'+chat_GravatarSize+'" align="left" />' +
      '<span class="Author '+EncodeHtml(author)+'">'+authorHtml+'</span> ' +
      '<span class="Text">'+txt+'</span>' +
      '</div>');
   return html;
}

function ArchiveMsg(id){
   RemoveElement($('#msg_'+id), 1000);
}

function DeleteMsg(id){
   RemoveElement($('#msg_'+id), 1000);
}

function Reply(username){
   $('#message').val('/msg '+GetMsgUsername(username) + ' ').focus();
}

function GetMsgUsername(username){
   return username.replace(' ', '_');
}

function ResizeChatArea(doScroll){
   if(InDebugMode() && (chat_IsFirstLoad || mi_IsFirstLoad || ou_IsFirstLoad)){
      alert('firstload stop');
   }
      

   /*
    * For some reason IE does not handle height() or css('height', x) 
    * properly when you use a calculated value, so we are very explicit
    * in setting the heights below.
    */

   // First grow as needed
   var ch;
   var prevHeight = $(document).height() + 1;
   while(prevHeight > $(document).height()){
      ch = parseInt($('#Chatter').css('height').replace('px',''));
      ch += 10;
      $('#Chatter').css('height',ch+'px');
   }

   var oh;
   prevHeight = $(document).height() + 1;
   while(prevHeight > $(document).height()){
      oh = parseInt($('#OtherUsers').css('height').replace('px',''));
      oh += 10;
      $('#OtherUsers').css('height',oh+'px');
   }

   prevHeight = $(document).height() + 1;
   while(prevHeight > $(document).height()){
      prevHeight = $(document).height();
      ch = parseInt($('#Chatter').css('height').replace('px',''));
      ch -= 1;
      oh = parseInt($('#OtherUsers').css('height').replace('px',''));
      oh -= 1;
      $('#Chatter').css('height',ch+'px');
      $('#OtherUsers').css('height',oh+'px');
   }
   if(doScroll){
      $("#Chatter").attr({ scrollTop: ($("#Chatter").attr("scrollHeight")) });
   }
}

function RemoveElement(sel, speed){
   $(sel).fadeOut(speed, function() { $(this).remove(); });
}

function ParseE2Date(str){
   /*
    * E2's tickers output dates in a format that can't be parsed by JavaScript's
    * built-in date methods, so we needed our own.
    */
   var arDt = str.split(' '); // split into date and time
   if (arDt.length == 2){
      var arYmd = arDt[0].split('-'); // split into year, month, day
      if (arYmd.length == 3){
         var arHms = arDt[1].split(':'); // split into hour, minute, second
         if (arHms.length == 3){
            return new Date(parseInt(arYmd[0]), parseInt(arYmd[1])-1, parseInt(arYmd[2]), parseInt(arHms[0]), parseInt(arHms[1]), parseInt(arHms[2]));
         }
      }else{
         return new Date(2000, 0, 1);
      }
   }else{
      return new Date(2000, 0, 1);
   }
}

/*
 * Generate a unique value that can be used to identify an element for scripting.
 * Statistically, given a large enough 'n' each value will be unique, though
 * of course it is possible that duplicate values could be generated.
 * Example: When n=10, there are 62^10 possible values (839+ quadrillion)
 */
function GenerateUniqueId(n){
   var chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
   var id = '';
   for (var i=0; i<n; i++) {
      var rnum = Math.floor(Math.random() * chars.length);
      id += chars.substring(rnum,rnum+1);
   }
   return id;
}

/*
 * Left-pads a number with zeros. Useful for outputing dates (i.e., months
 * and days).
 * Example: For April, output "04" instead of "4".
 */
function Pad(n,ln){
   var sn = n+'';
   while(sn.length<ln){
      sn = '0'+sn;
   }
   return sn;
}

/*
 * Basically, and symbol or non-ASCII character cases problems with jQuery
 * and/or CSS selectors. Some of the issues are obvious due to the syntax of
 * jQuery and CSS, but others may just be illegal characters for class names
 * and ids. This function removes inappropriate characters. The only
 * exception are dashes and underscores (which are legal), and spaces which
 * are converted to underscores instead of being removed.
 */
var regexpClassName = new RegExp('([^A-Za-z0-9_\\- ])','g');
function GetClassName(s){
   s = s.replace(/([^A-Za-z0-9_\-])/g, '_');
   //while(s.match(regexpClassName )){
   //   s = s.replace(regexpClassName, '');
   //}
   //while(s.indexOf(' ')>=0){
   //   s = s.replace(' ', '_');
   //}
   return s;
}

/*
 * This function is incomplete. Its purpose is (will be) to properly format messages
 * so they are output similarly to how [showchatter] outputs them. Examples of
 * messages that need formatting include: /me, /sing, /fireball, etc.
 */
function ParseMsgText(txt){
   return txt;
}

function Talk()
{
   var msg = $.trim($('#message').val());
   $('#message').val('');
   var checkmsg = ''; // this is temporary, in the future it will hold private msgs to be deleted
   if (msg.length > 0){
      $.ajax({
         type: 'POST',
         data: 'node=Universal Message XML Ticker&msglimit='+chat_MsgLimit+'&backtime=10&op=message&message='+encodeURIComponent(msg),
         url: '/index.pl',
         dataType: 'xml',
         timeout: 15000,
         contentType: 'application/x-www-form-urlencoded',
         success: ParseChatterbox
      });
      if(msg.indexOf('/msg')==0||msg.indexOf('/tell')==0){
         RefreshMessageInbox();
      }
   }else{
      RefreshChatterbox();
   }
}

/*
 *==============================================================================
 * OTHER USERS
 *==============================================================================
 */

function RefreshOtherUsers(){
   $.ajax({
      type: 'GET',
      url: '/index.pl?node=Other Users XML Ticker II&nosort=1',
      dataType: 'xml',
      success: ParseOtherUsers
   });
}

function IsKnownUser(username){
   var id = GetClassName(username);
   if ($('#OU_'+id).length > 0){
      return true;
   }
   return false;
}

function ParseOtherUsers(xml){
   // First loop through and add users
   var curUserCount = $('#OtherUsers').find('.OtherUser').length;
   var newUserCount = 0;
   $(xml).find("user").each(function()
   {
      author = $.trim($(this).find('e2link').text());
      if (!IsKnownUser(author)){
         InsertOtherUser($(this));
         newUserCount++;
      }
   });
   // Then loop through and remove users
   var found, username;
   $('#OtherUsers').find('.Username').each(function(){
      username = $.trim($(this).text());
      found = false;
      $(xml).find('e2link').each(function()
      {
         if($.trim($(this).text()).toUpperCase() == username.toUpperCase()){
            found=true;
            return;
         }
      });
      if(!found){
         RemoveElement('#OU_'+GetClassName(username), 5000);
      }
   });
   if(newUserCount>0){
      RemoveElement('.NewOu', 60000);
   }
   ou_IsFirstLoad = false;
   $('#ou_loading').css('visibility', 'hidden');
}

function InsertOtherUserUsername(username, isTemp){
   var inserted=false;
   var id = 'OU_'+GetClassName(username);
   var html;
   $('#OtherUsers').find('.Username').each(function(){
      if(inserted){return;}
      if(username.toUpperCase() <= $(this).text().toUpperCase()){
         html = '<div class="OtherUser" id="'+id+'"><a class="Username" href="/user/'+username+'">'+username+'</a>';
         if(!ou_IsFirstLoad){
            html += '<span class="NewOu">New Login</span>';
         }
         html += '</div>';
         $(this).parent().before(html);
         inserted=true;
         return;
      }
   });
   if(!inserted){
      html = '<div class="OtherUser" id="'+id+'"><a class="Username" href="/user/'+username+'">'+username+'</a>';
      if(!ou_IsFirstLoad){
         html += '<span class="NewOu">New Login</span>';
      }
      html += '</div>';
      $('#OtherUsers').append(html);
   }
   /*
    * Why temp? Because the other users nodelet is only updated every 5(?)
    * minutes, and we might discover other online users by watching the actual
    * chatter. Unfortunately, the universal message xml ticker does not tell us
    * who the editors, admins, coders, edev, ops, etc are. Therefore, we add a
    * temporary entry in the page's other users list, and add the 'official'
    * entry when the other users ticker updates itself.
    */
   if(isTemp){
      RemoveElement('#'+id, 30000);
   }
   return id;
}

function InsertOtherUser(ou){
   var inserted=false;
   var username = $.trim($(ou).find('e2link').text());
   var id = InsertOtherUserUsername(username, false);
   var md5 = $(ou).find('e2link').attr('md5');
   if(md5.length==32){
      $('#'+id).prepend('<img src="http://hnimagew.everything2.com/' + GetClassName(author) + '" alt="'+GetClassName(username)+'" height="'+ou_GravatarSize+'" width="'+ou_GravatarSize+'" /> ');
   }
   var position = '';
   if($(ou).attr('e2god')=='1'){position+='<abbr title="Administrator"> @ </abbr>';}
   if($(ou).attr('ce')=='1'){position+='<abbr title="Editor"> $ </abbr>';}
   if($(ou).attr('chanop')=='1'){position+='<abbr title="Chat Moderator"> ! </abbr>';}
   if($(ou).attr('committer')=='1'){position+='<abbr title="Sr. Developer"> * </abbr>';}
   if($(ou).attr('edev')=='1'){position+='<abbr title="Jr. Developer"> % </abbr>';}
   if(position.length>0){
      $('#'+id).append(' ('+position+')');
   }
}


function OtherUsersSort(a,b){
   if(a.username.toUpperCase()<b.username.toUpperCase()){
      return -1;
   }else{
      return 1;
   }
}

/*
 *========================================
 * General Methods
 *========================================
 */
function ShowNotification(s){
   var uniqueId = GenerateUniqueId(10);
   $('#Chatter').append('<div class="Note" id="s_'+uniqueId+'">'+s+'</div>');
   RemoveElement('#s_'+uniqueId, 45000);
   ResizeChatArea(true);
}

function GetUserUrl(u){
   return '/user/'+encodeURIComponent(u);
}

function GetUserLink(u){
   return '<a href="'+GetUserUrl(u)+'">'+EncodeHtml(u)+'</a>';
}

function EncodeHtml(t){  
  return $('<div/>').text(t).html();  
}  
 
function DecodeHtml(h){  
  return $('<div/>').html(h).text();  
} 

function SwapGravatars(){
   var g = $('#gravatarType').val();
   $("img[src*='gravatar.com']").each(function(){
      $(this).attr('src', $(this).attr('src').replace('?d=identicon&', '?d='+g+'&'));
      $(this).attr('src', $(this).attr('src').replace('?d=monsterid&', '?d='+g+'&'));
      $(this).attr('src', $(this).attr('src').replace('?d=wavatar&', '?d='+g+'&'));
   });
}
