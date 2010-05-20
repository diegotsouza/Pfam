
// FeatureViewer.js
//
// Javascript library which gets Features and renders it in the browser.
//
// $Id$

//------------------------------------------------------------------------------
//- OBJECT ---------------------------------------------------------------------
//------------------------------------------------------------------------------

// spoof a console, if necessary, so that we can run in IE (<8) without having
// to entirely disable debug messages
if ( ! window.console ) {
  window.console     = {};
  window.console.log = function() {};
}  

//------------------------------------------------------------------------------
//- class ----------------------------------------------------------------------
//------------------------------------------------------------------------------

// A Javascript library to use domainGraphics code to draw the protein features
// for respective das sources.

var FeatureViewer = Class.create({
  
  initialize: function( parent, accession, sources, url, options ){
    
    // check for an existing DOM element;
    if( parent !== undefined ){
      this.setParent( parent );
    }else{
      this._throw( 'parent cannot be null' );
    }
    
    // check for accession;
    if( accession !== undefined ){
      this.setAccession( accession );  
    }else{
      this._throw( 'Accession cannot be null' );
    }
     
    // check for sources; 
    if( sources !== undefined ){
      this.setSources( sources );
    }else{
      this._throw( 'Sources cannot be null' );
    }     
    
    // add the url
    if( /[\�\$\*\^]+/.test( url ) ){
      this._throw( "Input URL contains invalid characters");
    }else{
      this._url = url;
    } 
    
    // check whether tipStyle is defined in the options;
    if( options.tipStyle !== undefined ){
      // now the user is not interested in having their style, 
      // so we need to get the tip_definition.js file;
      this._fetchTipDefinition();
    }
    
    // also I need the CSS files to render the alignments in the page. 
    // so make a request to get the CSS files in the page using GET request;
    this._fetchCSS();
    
    //  initialise the other params for the feature viewer;
    // currently hard-coded maybe latter i could get it from options
    this._graphicXOffset = options.graphicXOffset || 10;
    this._extraXspace    = options.extraXspace    || 40;
    this._Yincrement     = options.Yincrement     || 20;
    this._resWidth       = options.resWidth       || 1;
    
    // initialise the image params for pfam graphic code
    this._imgParams     = { xscale:            1,
                          yscale:              1,
                          residueWidth:        this._resWidth,
                          envOpacity:          -1,
                          sequenceEndPadding:  0,
                          xOffset: this._graphicXOffset,  // das source names were written using canvas;
                         };
    
    // now test to make the use of the Yahoo's GET utility;
    this.fetchFeaturesByYahoo();
     
  }, // end of initialize function
  
  //----------------------------------------------------------------------------
  //- Methods ------------------------------------------------------------------
  //----------------------------------------------------------------------------
  
  // method to test YAHOO get utility;
  fetchFeaturesByYahoo: function(){
    
    var that = this;
    // now assuming that we are making a request, I am calling onLoading function;
    this.ajaxLoading();
    
    var sources = $A( this._sources );
    
    // now generate the query URL using the input accession and the source;
    //var queryString = url+'?acc='+ this._accession;
    var queryString = this._url+'?acc='+ this._accession;
    
    // now walk the sources array and add it to the query string;
    sources.each( function( dsn ){
      //// console.log('the dsn is '+dsn );
      queryString += '&sources=' + dsn ;
    } );
    // console.log( 'the final query string is '+queryString );
    
    var objTransaction = YAHOO.util.Get.script( queryString, { 
    onSuccess: function( response ){
        // now we got the featuers as JSON string;
        response.purge();
        
        that.ajaxComplete( features );
        
        // now set the readyState to true;
        that.setReadyState( true );
          
      }
    });
    
  },
  
//  // function to remove the loading image;
//  removeLoading: function(){
//    // console.log('the event is success, so remove the loading image' );
//    this._parent.removeChild( $( 'spinner' ) ); 
//  },
  //----------------------------------------------------------------------------
  
  // callback function for ajax request onComplete;
  ajaxComplete: function( features ){
    
    // remove the loading features child from shown;
    this._parent.removeChild( $('spinner') );
    
    //this._response = $H( eval ( '(' + features +')' ) );
    this._response = $H( features );
    //// console.log( 'the ajax response is '+$H( this._response ).inspect() );
    
    // parse the response and look for the error message;
    if( this._response.get( 'errorMsg') !== undefined ){
      // console.log("WE GOT AN ERROR" );
      this._throw( this._response.get( 'errorMsg') );  
    }
    
    // now create the canvas elements to draw the images ;
    this.buildCanvas();
    
    // retrieve the features and sources which returned data and draw them;
    this.drawCanvas();
    
    // by default show it off;
    this._parent.show();
  },
  
  //----------------------------------------------------------------------------
  
  // function to create the canvas element;
  buildCanvas: function(){
    
    // create the canvas element for the drawing if it doesnt exists in the dom;
    var imgCanvas, txtCanvas, scroller, backgroundDiv, wrapper;
    
    if( $( 'imgCanvas') === null && $( 'txtCanvas' ) === null ){
      imgCanvas = new Element( 'canvas',{ 'id': 'imgCanvas'} );
      txtCanvas = new Element( 'canvas',{ 'id': 'txtCanvas'} );
      
      // also create a wrapper div for img canvas, as we need this for taggin with alignment
      // viewer later;
      wrapper    = new Element( 'div', { 'id': 'canvasWrapper' } );
      scroller       = new Element( 'div', { 'id': 'scroller' } );
      backgroundDiv  = new Element( 'div', { 'id': 'backgroundDiv' } );
      
      wrapper.appendChild( imgCanvas );
      wrapper.appendChild( scroller );
      wrapper.appendChild( backgroundDiv );
      
      
      // make sure it gets initialised in bloody IE...
      if ( typeof G_vmlCanvasManager !== "undefined" ) {
        imgCanvas = G_vmlCanvasManager.initElement( imgCanvas );
        txtCanvas = G_vmlCanvasManager.initElement( txtCanvas );
      }
      
      // now add both the elements as child elements of the div;
      // CHECK: make sure there is no child elements of that parent.
      this._parent.appendChild( txtCanvas );
      //this._parent.appendChild( imgCanvas );
      this._parent.appendChild( wrapper );  
    }else{
      
      imgCanvas = $( 'imgCanvas' );
      txtCanvas = $( 'txtCanvas' );
      wrapper   = $( 'canvasWrapper' );
      scroller  = $( 'scroller' );
      backgroundDiv = $( 'backgroundDiv' );
      
    }

    //now set the canvas & the wrapper;
      
    if( imgCanvas !== undefined ){
      this.setimgCanvas( imgCanvas );  
    }
      
    if( txtCanvas !== undefined ){
      this.settxtCanvas( txtCanvas );  
    }
    
    if( wrapper !== undefined ){
      // console.log( 'the canvasWrapper is set '+wrapper );
      this.setCanvasWrapper( wrapper );
    }  
    
    // also set the scroller and backgroundDiv elements;
    this._scroller      = scroller;
    this._backgroundDiv = backgroundDiv;
    
    // now set the size of the canvas ;
    
    this._canvasHeight = this._response.get( 'dasTracks' ) * this._Yincrement;
    this._sequenceLength = ( this._response.get( 'seqLength' ) * this._resWidth );  // here the 1 is resWidth
    this._canvasWidth    = this._sequenceLength + this._graphicXOffset + this._extraXspace;
    
    // now set the canva height to be this value;
    imgCanvas.setAttribute( 'height', this._canvasHeight );
    imgCanvas.setAttribute( 'width', this._canvasWidth );
    txtCanvas.setAttribute( 'height', this._canvasHeight );
    //txtCanvas.setAttribute( 'width', 150 ); 
    // console.log( 'buildCanvas:the parent is '+this._parent);
  },
  
  //----------------------------------------------------------------------------
  drawCanvas:function(){
    
    // now get teh sources whcih returned some features;
//    this._featureSources = $A( eval( '('+ this._response.get( 'json_sources' ) + ')' ) );
//    this._dasFeatures    = $H( eval( '('+  this._response.get( 'dasFeatures' ) + ')' ) );
    this._featureSources = $A( this._response.get( 'json_sources' ) );
    this._dasFeatures    = $H( this._response.get( 'dasFeatures' ) );
    
    //// console.log('the feature and das sources are |%s|%s|',this._featureSources.inspect(), this._dasFeatures.inspect() );
    
    var parent         = this._parent;
    var featureSources = this._featureSources;
    var dasFeatures    = this._dasFeatures;
    var imgCanvas      = this._imgCanvas;
    var Yincrement     = this._Yincrement;
    var imgParams      = this._imgParams;
    
    // get the context for the canvases;
    if( this._imgCanvas.getContext ){
      // console.log( "canvas can be used in this browser" );
      ctx = this._imgCanvas.getContext( '2d' );
    }
    
    // get the context for text element;
    if ( this._txtCanvas.getContext ) {
      ttx = this._txtCanvas.getContext( '2d' );
      ttx.font = "bold 10px 'optimer'";
      ttx.textAlign = "center";
      ttx.textBaseline = "middle";
      ttx.lineWidth = 2;
    }  
    
    var baseline;  
    var graphicYOffset = 0 ;
    
    // walk down the featureSources and measure the maximum textWidth and use that for 
    // rendering the text;
    var textWidth = 0;
    featureSources.each( function( ds_id ){
      console.log( 'teh width is ' + ttx.measureText( ds_id ).width );
      
      // if the width is higher then use it;
      if( ttx.measureText( ds_id ).width > textWidth ){
        textWidth = ttx.measureText( ds_id ).width;
      }
      
    } );
    
    // now set the text canvas width to be the calculated value + 20 as fudge factor;
    this._txtCanvas.setAttribute( 'width', textWidth + 20 );  
    
    var pg1 = new PfamGraphic( parent );
    pg1.setCanvas( imgCanvas );
    pg1.setNewCanvas( false );  
    pg1.setImageParams( imgParams );
    // console.debug( pg1 );
        
    featureSources.each( function( ds_id ){
      var seqObj = $A( dasFeatures.get( ds_id ) );
      
      // now draw the track for each of the seqObject;
  	  seqObj.each( function( seq ){
        
        // draw the grpahic using the sequnece;
        pg1.setImageParams( { yOffset : graphicYOffset } );
        pg1.setSequence( seq );
        
        baseline = pg1.getBaseline();
        
        // draw the text
        ttx.strokeStyle = "#eeeeee";
        ttx.strokeText( ds_id, 5, graphicYOffset+baseline );
        ttx.strokeStyle = "#000000";
          
        // add the text here;
        ttx.fillStyle = 'black';
        ttx.fillText( ds_id, 5, graphicYOffset + baseline );
        
        pg1.render();
        // console.debug( "areas: ", pg1._areasList );
        
        graphicYOffset +=Yincrement; 
      } );
      
//      pg1.setImageParams( {yOffset: 0 });
    } );
    
    // now store the baseline and the graphicYOffset,
    // as these are required for tagging with the alignments;
    this._baseline = baseline;
    this._graphicYOffset = graphicYOffset; 
    
  },
  
  //----------------------------------------------------------------------------
 
  // callback function for ajax request loading;
  ajaxLoading: function(){
    var loadDiv = new Element( 'div',{ 'id': 'spinner' } );
    loadDiv.update( 'Loading Features...' );
    this._parent.appendChild( loadDiv );
  },
  
  //----------------------------------------------------------------------------
  
  // function to fetch the CSS files for rendering the alignment;
  _fetchCSS: function( ){
    console.log( 'making YAHOO get request for getting the CSS' );
    var cssTransaction1 = YAHOO.util.Get.css( 'http://localhost:3000/static/css/featureViewer.css',{
      onSuccess:function( o ){
        o.purge(); //removes the script node immediately after executing;
      }
      
    } );
      
  },
  
  //----------------------------------------------------------------------------
  
  // function to fetch the tip_definition file from my server;
  _fetchTipDefinition: function(){
    console.log( 'fetching the tipdefinition file for the tool tips' );
    
    var tipTransaction = YAHOO.util.Get.script( 'http://localhost:3000/static/javascripts/tip_definition.js',{
      onSuccess: function( o ){
        console.log( 'tip_definition loaded in the browser' );
        o.purge();
      }
    } );
    
  },
  //----------------------------------------------------------------------------
  //- Get and Set Methods ------------------------------------------------------
  //----------------------------------------------------------------------------
  
  // function to set parent;
  setParent: function( parent ){
    this._parent = $( parent );
    // console.log('the parent is '+this._parent.inspect() );
    
    if ( this._parent === undefined || this._parent === null ) {
      this._throw( "couldn't find the node"+parent );
    }
      
  },
  
  //--------------------------------------
  
  // function to get the parent;
  getParent: function(){
    return this._parent;
  },
  
  //----------------------------------------------------------------------------
  
  // function to set the accession;
  setAccession: function( accession ){
    this._accession = accession;
    
    //check whether we get the accession as a string;
    if( this._accession === null ){
      this._throw( 'Accession cannot be null' );
    }
    
    // use regex to check we get any invalid characters in the string;
    if( /\W+/.test( this._accession ) ){
      this._throw( 'Accession contains invalid characters');
    }
    
    
  }, // end of setAccession
  
  //-------------------------------------
  
  // function to return the accession 
  getAccession: function(){
    return this._accession;
  },
  
  //----------------------------------------------------------------------------
  
  // function to set the das sources;
  setSources: function( sources ){
    this._sources = sources;
    
    // check the sources whether its an array
    if( typeof this._sources !== 'object' ){
      this._throw('Sources is not an Javascript object');
    }
    
    // check whether the array has got contents;
    if( this._sources.length == undefined ){
      this._throw( 'Input sources doesnt contain values');
    }
    
  },
  
  //-------------------------------------
  
  // function to get the input das sources;
  getSources: function( ){
    return this._sources;
  },
  
  //----------------------------------------------------------------------------
  
  // function to set the image canvas;
  setimgCanvas: function( canvas ){
    if( canvas !== undefined ){
      this._imgCanvas = canvas;
    }else{
      this._throw( 'imgCanvas could not be created' );
    }
    
  },
  
  //-------------------------------------
  
  // function to get the image canvas;
  getimgCanvas: function(){
    return this._imgCanvas;
  },
  
  //----------------------------------------------------------------------------
  
  // function to set the text canvas;
  settxtCanvas: function( canvas ){
    if( canvas !== undefined ){
      this._txtCanvas = canvas;
    }else{
      this._throw( 'txtCanvas could not be created' );
    }
    
  },
  
  //-------------------------------------
  
  // function to get the txt canvas;
  gettxtCanvas: function(){
    return this._txtCanvas;
  },
  
  //----------------------------------------------------------------------------
  
  // function to set the wrapper;
  setCanvasWrapper: function( wrapper ){
    if( wrapper !== undefined ){
      this._canvasWrapper = wrapper ;
    }else{
      this._throw( 'canvasWrapper was not created' );
    }  
  },
  
  //-------------------------------------
  
  getCanvasWrapper: function(){
    return this._canvasWrapper;
  },
  
  //----------------------------------------------------------------------------
  
  // function to set the readyState of this object;
  setReadyState: function( status ){
    this._readyState = status;  
  },
  
  //--------------------------------------
  
  getReadyState: function( ){
    return this._readyState;
  },
  
  //----------------------------------------------------------------------------
  //- Private methods ----------------------------------------------------------
  //----------------------------------------------------------------------------
  
  _throw: function( message ) {
    throw { name: "FeatureViewerException",
            message: message,
            toString: function() { return this.message; } };
  } 
  
  //----------------------------------------------------------------------------
  
}); // end of Class.create;
