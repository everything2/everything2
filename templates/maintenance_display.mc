<%flags>
    extends => '/zen.mc'
</%flags>
Maintains: <& '/helpers/linknode.mi', 'node' => $.node->maintains &><br>
<p>
Maintenance operation: <% $.node->maintaintype %>
<p><pre><% $.node->code_text %></pre>
