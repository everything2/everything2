<h1>What's a "linebreaker?"</h1>

<p>This is intended for use with [lyric]s and poetry, where you may have dozens of lines and you need a <tt>&lt;br&gt;</tt>  tag at the end of each line.  </p>

<p>If you're doing ordinary prose, don't use this thing. For that, you should <i>enclose</i> each paragraph in <tt>&lt;p&gt; &lt;/p&gt;</tt> tags,
like so: </p>

<pre>
    <font color="#a00000">&lt;p&gt;</font>[Just don't call me late for dinner|Call me Ishmael].  Some years ago -- never mind how long 
    precisely -- having little or no money in my purse, and 
    nothing particular to interest me on shore, I thought I 
    would sail about a little and see the watery part of the 
    world. <font color="#a00000">&lt;/p&gt;</font>

    <font color="#a00000">&lt;p&gt;</font>-- [Herman's Hermits|Herman Melville] <font color="#a00000">&lt;/p&gt;</font>
</pre>

<p>The [E2 Paragraph Tagger] does exactly that, with a few options thrown in. </p>

<p>It's permissible to use just the "open paragraph" tag (<tt>&lt;p&gt;</tt>) at the <i>beginning</i> of 
<i>each</i> paragraph, but don't leave that out and put a "close paragraph" tag (<tt>&lt;/p&gt;</tt>) at the 
end of each paragraph; that's broken HTML and it causes formatting problems in some browsers. Note 
that putting a '/' at the end of the tag is not the same thing as putting it at the beginning: At the beginning 
(as in <tt>&lt;/p&gt;</tt> or <tt>&lt;/i&gt;</tt>), it means that the tag is a "close" tag; at the end (as in 
<tt>&lt;br /&gt;</tt>), it signifies that the tag is an "open" tag which <i>has no</i> matching "close" tag. 
Most tags, like <tt>&lt;p&gt;</tt> "contain" things; <tt>&lt;br /&gt;</tt> is a rare exception.</p>

<h1>Here's how it works:</h1>

<p>First paste your writeup into the box, then click the <b>"Add Break Tags"</b> button down below the box. The Linebreaker will insert a <tt>&lt;br&gt;</tt>  tag wherever you hit the "return" key in the text. Where the lines wrap around without hitting "return", that will be ignored. </p>

<p>If you select the <b>"Replace indenting with <tt>&lt;dd&gt;</tt>  tag"</b> option, the Linebreaker will insert a <tt>&lt;dd&gt;</tt>  tag at the beginning of every line which has been indented with one or more spaces or tabs. The <tt>&lt;dd&gt;</tt>  tag will indent the line when you display your writeup. </p>

<dl>
<dt>Along similar lines:</dt>
<dd>You can E2-proof source code (and reverse the process) with the [E2 Source Code Formatter]. </dd>
<dd>[E2 Paragraph Tagger]</dd>
<dd>You can also format lists as HTML with the [E2 List Formatter]. </dd>
</dl>


      <!--  wharfinger  9/11/00                                    -->
      <!--  This "code", such as it is, is in the public domain.   -->

      <!--  We give the user a text-edit widget, and the user can  -->
      <!--  copy/paste a writeup into it.  The user then clicks    -->
      <!--  "submit", and we add <br> tags to the ends of all the  -->
      <!--  lines and select the whole text in the edit.  The      -->
      <!--  user can then very conveniently copy and paste the     -->
      <!--  break-tagged text back into, like, whatever.           -->

      <script language="JavaScript">
      <!--
          //---------------------------------------------------------------------
          function do_replace( widget ) {
              widget.value = add_br( widget.value, 
                                     document.breaktagger.fixtabs.checked );
              widget.select();
              widget.focus();

              return false;   //  Even if this was invoked by a "submit" button,
                              //  don't submit.
          }

          //---------------------------------------------------------------------
          function add_br( str, fix_tabs ) {
              //  Props to dbrown for rephrasing the regular expressions below; 
              //  the second is more pleasing than what I had, and both of them 
              //  avoid E2 Square Bracket Hell.
              if ( fix_tabs )
                  str = str.replace( /(\r\n|\r|\n)(\t| )+/g, '$1<dd>' );

              //  (\r\n|\r|\n):  Allow for Windows/DOS/UNIX/Mac newline madness.  
              //  We remove all old break tags, provided they're at the ends of 
              //  lines.  We also remove all trailing whitespace, while we're at
              //  it.  I'm tidy that way.
              return str.replace( /(<br>|<br\/>|<br \/>|\t| )*(\r\n|\r|\n)/g, ' <br />$2' );
          }
      //-->
      </script>

  <noscript>
      <p><font color="#800000"><b>
      This is not going to work, because you don't have JavaScript.
      You may not have it at all, or you may just have it disabled.  It comes 
      to the same thing either way.
      </b></font></p>
  </noscript>

  <form name="breaktagger">
      <textarea name="edit" cols="70" rows="20"></textarea>
      <br>

      <input type="button" name="submit" value="Add Break Tags"
          OnClick="return do_replace( document.breaktagger.edit )"></input>

      <input type="checkbox" name="fixtabs" value="0">
          Replace indenting with <tt>&lt;dd&gt;</tt> tag</input>
  </form>

<br><br><br><br><br>
<hr>
<p>6/5/2001: Updated to generate XHTMLically correct <tt>&lt;br /&gt;</tt> tags and to harangue users 
about broken HTML. </p>
