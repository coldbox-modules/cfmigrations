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
			"managers" : {
				"default" : {
					"manager" : "cfmigrations.models.QBMigrationManager",
					"properties" : {
						"defaultGrammar" : "BaseGrammar"
					}
				}
			}
		};

	}

	function onLoad(){
		settings.managers.keyArray().each( function( key ){
			binder
				.map( "MigrationService:" & key )
				.to( "#moduleMapping#.models.MigrationService" )
				.initWith( argumentCollection=settings.managers[ key ] );
		} );

	}

}
