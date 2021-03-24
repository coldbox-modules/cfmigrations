component {

	this.name          = "cfmigrations";
	this.author        = "Eric Peterson";
	this.description   = "Keep track and run your database migrations with CFML";
	this.version       = "0.0.0";
	this.cfmapping     = "cfmigrations";
	this.autoMapModels = false;
	this.dependencies  = [ "qb" ];

	function configure() {
		settings = {
			defaultGrammar      : "BaseGrammar"
		};

	}

	function onLoad(){
		if( !settings.keyExists( "managers" ) ){

			if( settings.keyExists( "defaultGrammar" ) && listLen( settings.defaultGrammar, "." ) < 2 ){
				settings.defaultGrammar &= "@qb";
			}

			binder
				.map( "MigrationService@cfmigrations" )
				.to( "#moduleMapping#.models.MigrationService" )
				.initWith( argumentCollection=settings );
		} else {
			settings.managers.keyArray().each( function( key ){
				binder
					.map( "MigrationService:" & key )
					.to( "#moduleMapping#.models.MigrationService" )
					.initWith( argumentCollection=settings.managers[ key ] );
			} );
		}

	}

}
