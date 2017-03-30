// 2067939.js "Autoformat javascript"
// Unknown usage

function autoFormat (id)
{
  var elem = document.getElementsByName(id).item(0);
  var text = elem.value;
  var blocks = "pre|center|li|ol|ul|h1|h2|h3|h4|h5|h6" +
    "|blockquote|dd|dt|dl|p" +
    "|table|td|tr|th";

  text = '<p>' + text
    // strip out existing formatting 
    .replace (new RegExp('</?p>', 'ig'), '')
    .replace (new RegExp('<br */?>', 'ig'), '')
    // Strip out leading and trailing space
    .replace (new RegExp('\\s*$', 'ig'), '')
    .replace (new RegExp('^\\s*', 'ig'), '')
    // New formatting
    .replace (new RegExp("\n", 'ig'), "<br />\n")
    .replace (new RegExp("<br />\n(<br />\n)+", 'ig'), "</p>\n\n<p>")
    + '</p>';
  text = text
    // Fix block elements
    .replace (new RegExp('<p><('+blocks+'[ >])', 'ig'), '<$1')
    .replace (new RegExp('</('+blocks+')></p>', 'ig'), '</$1>');

  elem.value = text;

}
