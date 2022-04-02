<%flags>
    extends => '/zen.mc'
</%flags>
Maintains: <& 'linknode', 'node' => $.node->maintains &><br>
<p>
Maintenance operation: <% $.node->maintaintype %>
<p><pre><% $.node->code_text %></pre>
