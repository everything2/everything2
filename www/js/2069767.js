// 2069767.js colorclass.js
// Unknown usage

//  JavaScript class for handling colors
//  1/24/02

//-----------------------------------------------------------------------------
//  Named colors
var NAMED = new Object();
//  Which of the named colors are fake.
var FAKE  = new Object();
initNamedColors();

//-----------------------------------------------------------------------------
//  These are IntRange instances. They are properly initalized below, after the 
//  IntRange class is fully defined.
var RGBRange    = null; //  RGB values
var HueRange    = null; //  Hue
var SatBriRange = null; //  Saturation and brightness

//-----------------------------------------------------------------------------
function zpadl( s, digits ) {
    while ( s.length < digits )
        s = "0" + s;
    return s;
}


function toHex( x, digits ) {
    var n = parseInt( x.toString() );

    if ( digits == null )
        digits = 1;

    if ( isNaN( n ) )
        n = 0;

    return zpadl(n.toString( 16 ), 2 );
}


//-----------------------------------------------------------------------------
function IntRange( low, high, dflt ) {
    this.set( low, high, dflt );
}

IntRange.prototype.low      = 0;
IntRange.prototype.high     = 255;
IntRange.prototype.dflt     = 0;

IntRange.prototype.set = function( low, high, dflt ) {
    if ( low != null ) {
        this.low = parseInt( low );
        if ( isNaN( this.low ) )
            this.low = IntRange.prototype.low;
    }

    if ( high != null ) {
        this.high = parseInt( high );
        if ( isNaN( this.high ) )
            this.high = IntRange.prototype.high;
    }

    if ( dflt != null ) {
        this.dflt = parseInt( dflt );
        if ( isNaN( this.dflt ) )
            this.dflt = IntRange.prototype.dflt;
    }

    return this;
}

//  If n is a string that might not be base 10, provide a radix
IntRange.prototype.enforceOn = function( n, radix ) {
    n = parseInt( n, radix );

    if ( isNaN( n ) )
        return this.dflt;
    else if ( n < this.low )
        return this.low;
    else if ( n > this.high )
        return this.high;
    else
        return n;
}


//-----------------------------------------------------------------------------
//  Due to the weird JS object model, IntRange() exists before we define it. 
//  This is because it is declared, so it exists as soon as the file is parsed. 
//  Its member functions, however, aren not added until *execution* of the file 
//  gets to that point: They are assignments rather than declarations. If we do 
//  this before then, we get errors because the constructor calls 
//  IntRange.prototype.set, which remains undefined until we assign a function 
//  object to it. 
RGBRange    = new IntRange( 0, 255, 0 );    //  RGB values
HueRange    = new IntRange( 0, 419, 0 );    //  Hue
SatBriRange = new IntRange( 0, 100, 0 );    //  Saturation and brightness


//-----------------------------------------------------------------------------
function htmlColor( r, g, b ) {
    return "#" + toHex(r, 2 ) + toHex(g, 2 ) + toHex(b, 2 );
}

function namedColorValue( s ) {
    var s = NAMED[ s ];

    return ( ( "" + s ) == "undefined" ) ? "#000000" : s;
}


//-----------------------------------------------------------------------------
//  This one is the whole point.
//  Constructor:
//      Color( a, b, c )    //  If all arguments are null, default to 0, 0, 0;
//                          //  If b or c is null but a is not, call 
//                          //  this.fromString( a );
//                          //  Otherwise, call this.fromRGB( a, b, c ).
//
//  Members:
//      r, g, b             //  Red, green, and blue values.
//
//      fromString( s )     //  If the first character of s is "#", s is 
//                          //  presumed to be an HTML hex color string. 
//                          //  Otherwise, it is presumed to be a named HTML 
//                          //  color.
//
//      toString()          //  return HTML hex color string: #RRGGBB
//      fromRGB( r, g, b )  //  Initialize from red, green, and blue values
//      fromHSB( h, s, b )  //  Initialize from hue, saturation, and brightness
//      toHSB()             //  return HSB object w/ h, s, and b members
//
//      getRGBSorted()      //  return an Object with min, max, and mid members.
//                          //  We use it internally.
//-----------------------------------------------------------------------------
function Color( a, b, c ) {
    if ( a != null ) {
        if ( b == null && c == null ) {
            this.fromString( a );
        } else {
            this.fromRGB( a, b, c );
        }
    }
}

Color.prototype.r   = 0;
Color.prototype.g   = 0;
Color.prototype.b   = 0;

Color.prototype.fromRGB = function( r, g, b ) {
    this.r = RGBRange.enforceOn( r );
    this.g = RGBRange.enforceOn( g );
    this.b = RGBRange.enforceOn( b );

    return this;
}

Color.prototype.toString = function() {
    return htmlColor( this.r, this.g, this.b );
}

Color.prototype.fromString = function( s ) {
    s = (s + "").toString();

    if ( s.substr( 0, 1 ) != "#" )
        s = namedColorValue( s );

    s = zpadl( s.replace( /^[^0-9a-f]/gi, "" ), 6 );

    var clrs = s.match( /([0-9a-f][0-9a-f])/gi );

    this.r = RGBRange.enforceOn( clrs[ 0 ], 16 );
    this.g = RGBRange.enforceOn( clrs[ 1 ], 16 );
    this.b = RGBRange.enforceOn( clrs[ 2 ], 16 );

    return this;
}

Color.prototype.fromHSB = function( hue, sat, bright ) {
    sat /= 100;
    bright /= 100;

    if ( sat == 0 ) {
        this.r = bright;
        this.g = bright;
        this.b = bright;

        return this;
    } else {
        hue = hue / 60;
        var i = Math.floor( hue );
        var f = hue - i;
        var p = bright * ( 1.0 - sat );
        var q = bright * ( 1.0 - sat * f );
        var t = bright * ( 1.0 - sat * ( 1.0 - f ) );

        bright *= 255;
        t *= 255;
        p *= 255;
        q *= 255;

        switch ( i ) {
            case 0:
                return this.fromRGB( bright, t, p );

            case 1:
                return this.fromRGB( q, bright, p );

            case 2:
                return this.fromRGB( p, bright, t );

            case 3:
                return this.fromRGB( p, q, bright );

            case 4:
                return this.fromRGB( t, p, bright );

            default:
                return this.fromRGB( bright, p, q );
        }
    }
}


Color.prototype.getRGBSorted = function() {
    var ary = new Array( this.r, this.b, this.g );

    //  Make sure we sort these as integers, not strings.
    //  According to Netscape JS documentation, the callback will not work with 
    //  some pre-v4 versions of Netscape on some platforms. Or something. Maybe 
    //  it was version 2. 
    ary.sort( function( a, b ) { return parseInt( a ) - parseInt( b ); } );

    /*
    var rtn = new Object();

    rtn.min = ary[ 0 ];
    rtn.mid = ary[ 1 ];
    rtn.max = ary[ 2 ];

    alert( rtn.toSource() );

    return rtn;
    */

    //  Object literal. Ph334r my 1337 skillz.
    return { min: ary[ 0 ], mid: ary[ 1 ], max: ary[ 2 ] };
}


Color.prototype.toHSB = function() {
    var domainBase      = 0;
    var domainOffset    = 0;

    var hsb = new HSB();
    var mmm = this.getRGBSorted();

    if ( mmm.max == 0 ) {
        hsb.b = 0;
        hsb.s = 0;
    } else {
        hsb.b = mmm.max / 255;
        hsb.s = ( hsb.b - ( mmm.min / 255.0 ) ) / hsb.b;
    }

    var oneSixth = 1.0 / 6.0;

    domainOffset = ( mmm.mid - mmm.min ) / ( mmm.max - mmm.min ) / 6.0;

    if ( mmm.max == mmm.min ) {
        hsb.h = 0;
    } else {
        if ( this.r == mmm.max ) {
            if ( mmm.mid == this.g ) {
                domainBase = 0 / 6.0;
            } else {
                domainBase = 5 / 6.0;
                domainOffset = oneSixth - domainOffset;
            }
        } else if ( this.g == mmm.max ) {
            if ( mmm.mid == this.b ) {
                domainBase = 2 / 6.0;
            } else {
                domainBase = 1 / 6.0;
                domainOffset = oneSixth - domainOffset;
            }
        } else {
            if ( mmm.mid == this.r ) {
                domainBase = 4 / 6.0;
            } else {
                domainBase = 3 / 6.0;
                domainOffset = oneSixth - domainOffset;
            }
        }

        hsb.h = domainBase + domainOffset;
    }

    hsb.h = Math.round( hsb.h * 360 );
    hsb.s = Math.round( hsb.s * 100 );
    hsb.b = Math.round( hsb.b * 100 );

    return hsb.integerize();
}


//-----------------------------------------------------------------------------
//  This HSB class is primitive. Think of it as a struct with functions rather
//  than a real class. It exists only so Color.toHSB() has a type to return.
//-----------------------------------------------------------------------------
function HSB( h, s, b ) {
    this.h = h || 0;
    this.s = s || 0;
    this.b = b || 0;
}

HSB.prototype.integerize = function() {
    this.h = parseInt( this.h );
    this.s = parseInt( this.s );
    this.b = parseInt( this.b );

    return this;
}

HSB.prototype.toString = function() {
    return this.toColor().toString();
}


HSB.prototype.toColor = function() {
    return new Color().fromHSB( this.h, this.s, this.b );
}


//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
function initNamedColors() {
    NAMED[ "snow" ]                 = "#fffafa";
    NAMED[ "ghostwhite" ]           = "#f8f8ff";
    NAMED[ "whitesmoke" ]           = "#f5f5f5";
    NAMED[ "gainsboro" ]            = "#dcdcdc";
    NAMED[ "floralwhite" ]          = "#fffaf0";
    NAMED[ "oldlace" ]              = "#fdf5e6";
    NAMED[ "linen" ]                = "#faf0e6";
    NAMED[ "antiquewhite" ]         = "#faebd7";
    NAMED[ "papayawhip" ]           = "#ffefd5";
    NAMED[ "blanchedalmond" ]       = "#ffebcd";
    NAMED[ "bisque" ]               = "#ffe4c4";
    NAMED[ "peachpuff" ]            = "#ffdab9";
    NAMED[ "navajowhite" ]          = "#ffdead";
    NAMED[ "moccasin" ]             = "#ffe4b5";
    NAMED[ "cornsilk" ]             = "#fff8dc";
    NAMED[ "ivory" ]                = "#fffff0";
    NAMED[ "lemonchiffon" ]         = "#fffacd";
    NAMED[ "seashell" ]             = "#fff5ee";
    NAMED[ "honeydew" ]             = "#f0fff0";
    NAMED[ "mintcream" ]            = "#f5fffa";
    NAMED[ "azure" ]                = "#f0ffff";
    NAMED[ "aliceblue" ]            = "#f0f8ff";
    NAMED[ "lavender" ]             = "#e6e6fa";
    NAMED[ "lavenderblush" ]        = "#fff0f5";
    NAMED[ "mistyrose" ]            = "#ffe4e1";
    NAMED[ "white" ]                = "#ffffff";
    NAMED[ "black" ]                = "#000000";
    NAMED[ "darkslategray" ]        = "#2f4f4f";
    NAMED[ "dimgray" ]              = "#696969";
    NAMED[ "slategray" ]            = "#708090";
    NAMED[ "lightslategray" ]       = "#778899";
    NAMED[ "gray" ]                 = "#bebebe";
    NAMED[ "lightgray" ]            = "#d3d3d3";
    NAMED[ "midnightblue" ]         = "#191970";
    NAMED[ "cornflowerblue" ]       = "#6495ed";
    NAMED[ "darkslateblue" ]        = "#483d8b";
    NAMED[ "slateblue" ]            = "#6a5acd";
    NAMED[ "mediumslateblue" ]      = "#7b68ee";
    NAMED[ "mediumblue" ]           = "#0000cd";
    NAMED[ "royalblue" ]            = "#4169e1";
    NAMED[ "blue" ]                 = "#0000ff";
    NAMED[ "dodgerblue" ]           = "#1e90ff";
    NAMED[ "deepskyblue" ]          = "#00bfff";
    NAMED[ "skyblue" ]              = "#87ceeb";
    NAMED[ "lightskyblue" ]         = "#87cefa";
    NAMED[ "steelblue" ]            = "#4682b4";
    NAMED[ "lightsteelblue" ]       = "#b0c4de";
    NAMED[ "lightblue" ]            = "#add8e6";
    NAMED[ "powderblue" ]           = "#b0e0e6";
    NAMED[ "paleturquoise" ]        = "#afeeee";
    NAMED[ "darkturquoise" ]        = "#00ced1";
    NAMED[ "mediumturquoise" ]      = "#48d1cc";
    NAMED[ "turquoise" ]            = "#40e0d0";
    NAMED[ "cyan" ]                 = "#00ffff";
    NAMED[ "lightcyan" ]            = "#e0ffff";
    NAMED[ "cadetblue" ]            = "#5f9ea0";
    NAMED[ "mediumaquamarine" ]     = "#66cdaa";
    NAMED[ "aquamarine" ]           = "#7fffd4";
    NAMED[ "darkgreen" ]            = "#006400";
    NAMED[ "darkolivegreen" ]       = "#556b2f";
    NAMED[ "darkseagreen" ]         = "#8fbc8f";
    NAMED[ "seagreen" ]             = "#2e8b57";
    NAMED[ "mediumseagreen" ]       = "#3cb371";
    NAMED[ "lightseagreen" ]        = "#20b2aa";
    NAMED[ "palegreen" ]            = "#98fb98";
    NAMED[ "springgreen" ]          = "#00ff7f";
    NAMED[ "lawngreen" ]            = "#7cfc00";
    NAMED[ "chartreuse" ]           = "#7fff00";
    NAMED[ "greenyellow" ]          = "#adff2f";
    NAMED[ "limegreen" ]            = "#32cd32";
    NAMED[ "forestgreen" ]          = "#228b22";
    NAMED[ "green" ]                = "#00ff00";
    NAMED[ "olivedrab" ]            = "#6b8e23";
    NAMED[ "yellowgreen" ]          = "#9acd32";
    NAMED[ "darkkhaki" ]            = "#bdb76b";
    NAMED[ "palegoldenrod" ]        = "#eee8aa";
    NAMED[ "lightgoldenrodyellow" ] = "#fafad2";
    NAMED[ "lightyellow" ]          = "#ffffe0";
    NAMED[ "yellow" ]               = "#ffff00";
    NAMED[ "gold" ]                 = "#ffd700";
    NAMED[ "goldenrod" ]            = "#daa520";
    NAMED[ "darkgoldenrod" ]        = "#b8860b";
    NAMED[ "rosybrown" ]            = "#bc8f8f";
    NAMED[ "indianred" ]            = "#cd5c5c";
    NAMED[ "saddlebrown" ]          = "#8b4513";
    NAMED[ "sienna" ]               = "#a0522d";
    NAMED[ "peru" ]                 = "#cd853f";
    NAMED[ "burlywood" ]            = "#deb887";
    NAMED[ "beige" ]                = "#f5f5dc";
    NAMED[ "wheat" ]                = "#f5deb3";
    NAMED[ "sandybrown" ]           = "#f4a460";
    NAMED[ "tan" ]                  = "#d2b48c";
    NAMED[ "chocolate" ]            = "#d2691e";
    NAMED[ "firebrick" ]            = "#b22222";
    NAMED[ "brown" ]                = "#a52a2a";
    NAMED[ "darksalmon" ]           = "#e9967a";
    NAMED[ "salmon" ]               = "#fa8072";
    NAMED[ "lightsalmon" ]          = "#ffa07a";
    NAMED[ "orange" ]               = "#ffa500";
    NAMED[ "darkorange" ]           = "#ff8c00";
    NAMED[ "coral" ]                = "#ff7f50";
    NAMED[ "lightcoral" ]           = "#f08080";
    NAMED[ "tomato" ]               = "#ff6347";
    NAMED[ "orangered" ]            = "#ff4500";
    NAMED[ "red" ]                  = "#ff0000";
    NAMED[ "hotpink" ]              = "#ff69b4";
    NAMED[ "deeppink" ]             = "#ff1493";
    NAMED[ "pink" ]                 = "#ffc0cb";
    NAMED[ "lightpink" ]            = "#ffb6c1";
    NAMED[ "palevioletred" ]        = "#db7093";
    NAMED[ "maroon" ]               = "#b03060";
    NAMED[ "mediumvioletred" ]      = "#c71585";
    NAMED[ "magenta" ]              = "#ff00ff";
    NAMED[ "violet" ]               = "#ee82ee";
    NAMED[ "plum" ]                 = "#dda0dd";
    NAMED[ "orchid" ]               = "#da70d6";
    NAMED[ "mediumorchid" ]         = "#ba55d3";
    NAMED[ "darkorchid" ]           = "#9932cc";
    NAMED[ "darkviolet" ]           = "#9400d3";
    NAMED[ "blueviolet" ]           = "#8a2be2";
    NAMED[ "purple" ]               = "#a020f0";
    NAMED[ "mediumpurple" ]         = "#9370db";
    NAMED[ "thistle" ]              = "#d8bfd8";
    //  fake
    NAMED[ "wharfkhaki" ]           = "#d5d1c1";
    NAMED[ "wharfolive" ]           = "#6e6d56";
    NAMED[ "jukkaback" ]            = "#ddddbb";
    NAMED[ "jukkaodd" ]             = "#cccc99";
    NAMED[ "jukkabrown" ]           = "#7e7e66";

    FAKE[ "wharfkhaki" ]        = true;
    FAKE[ "wharfolive" ]        = true;
    FAKE[ "jukkaback" ]         = true;
    FAKE[ "jukkaodd" ]          = true;
    FAKE[ "jukkabrown" ]        = true;
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

