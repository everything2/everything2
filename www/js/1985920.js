// 1985920.js sortlist
// Used in showbookmarks

// by Bruno Bornsztein - www.feedmarker.com or blog.feedmarker.com
// You're free to use this however you want. You can even take this
// attribution out if you like.

// Make sure the list you want to sort has a unique id Then create a
// link to sort the list in the following format: <a
// href="javascript:void(0);" onclick="sort(this)" list_id="the id of
// the list you want to sort" order="asc or desc">Sort</a> that will
// just just the list by it list item values

// if you want to sort by an attribute you've included within each
// list item (i.e. <LI size="10">), just do this: // <a
// href="javascript:void(0);" onclick="sort(this)" list_id="the id of
// the list you want to sort" order="asc or desc" sortby="your
// attribute">Sort</a>

function ts_getInnerText(el) {
  //Thanks to http://www.kryogenix.org/code/browser/sorttable/ for this function
	if (typeof el == "string") return el;
	if (typeof el == "undefined") { return el; };
	if (el.innerText) return el.innerText;	//Not needed but it is faster
	var str = "";

	var cs = el.childNodes;
	var l = cs.length;
	for (var i = 0; i < l; i++) {
		switch (cs[i].nodeType) {
		case 1: //ELEMENT_NODE
			str += ts_getInnerText(cs[i]);
			break;
		case 3:	//TEXT_NODE
			str += cs[i].nodeValue;
			break;
		}
	}
	return str;
}


function ts_getInnerText(el) {
	if (typeof el == "string") return el;
	if (typeof el == "undefined") { return el; };
	if (el.innerText) return el.innerText;	//Not needed but it is faster
	var str = "";

	var cs = el.childNodes;
	var l = cs.length;
	for (var i = 0; i < l; i++) {
		switch (cs[i].nodeType) {
		case 1: //ELEMENT_NODE
			str += ts_getInnerText(cs[i]);
			break;
		case 3:	//TEXT_NODE
			str += cs[i].nodeValue;
			break;
		}
	}
	return str;
}

function parse_list_to_array(list_id, attribute){
	var list = document.getElementById(list_id);
	var cs = list.childNodes;
	var list_array = new Array();

	var l = cs.length;
	for (var i = 0; i < l; i++) {
    node = cs[i];
    if (node.nodeName == "LI"){
      if(!attribute){
        var value = ts_getInnerText(node);
        list_array.push([node, value]);
      } else{
        list_array.push([node, node.getAttribute(attribute)]);
      }
	  }
  }

  //returns an array with the node in [0] and the attribute in [1]
  return list_array;
}


function sort(link){

  var list_id = link.getAttribute('list_id');
  var order = link.getAttribute('order');
  var sortby = link.getAttribute('sortby');

  if (order == 'desc'){
    order = 'asc';
    link.setAttribute('order','asc');
  } else {
    order = 'desc';
    link.setAttribute('order','desc');
  }

  var array = parse_list_to_array(list_id, sortby);

  // Work out a type to sort by
  var itm = array[1][1];
  var sortfn = mysortfn_by_attribute;
  if (itm.match(/^[\d\.]+$/)) sortfn = ts_sort_numeric;


  array.sort(sortfn);

  switch (order){
  case "desc":
    array.reverse();
    break;
  }

  var list = document.getElementById(list_id);

  for (var k = 0; k < array.length; k++){
    list.appendChild(array[k][0]);
  }

  return;
}

function mysortfn_by_attribute(a,b) {

  // Note that each thing we are passed is an array, so we don't
  // compare the things we're passed; instead, we compare their second
  // column

  if (a[1]<b[1]) return -1;
  if (a[1]>b[1]) return 1;
  return 0;
}

function ts_sort_numeric(a,b) {
  var aa = a[1];
  if (isNaN(aa)) aa = 0;
  var bb = b[1];
  if (isNaN(bb)) bb = 0;
  return bb-aa;
}
