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
			"manager" : "cfmigrations.models.QBMigrationManager",
			"properties" : {
				"defaultGrammar" : "BaseGrammar"
			}
		};

	}

	function onLoad(){
		if( isSimpleValue( settings.manager ) ){
			if( settings.properties.keyExists( "defaultGrammar" ) && listLen( settings.properties.defaultGrammar, "." ) < 2 ){
				settings.properties.defaultGrammar &= "@qb";
			}

			binder
				.map( "MigrationService@cfmigrations" )
				.to( "#moduleMapping#.models.MigrationService" )
				.initWith( argumentCollection=settings );
		} else {
			settings.manager.keyArray().each( function( key ){
				binder
					.map( "MigrationService:" & key )
					.to( "#moduleMapping#.models.MigrationService" )
					.initWith( argumentCollection=settings.managers[ key ] );
			} );
		}

	}

}
