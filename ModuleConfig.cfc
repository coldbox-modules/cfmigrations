component {

    this.name = "cfmigrations";
    this.author = "Eric Peterson";
    this.description = "Keep track and run your database migrations with CFML";
    this.version = "0.0.0";
    this.cfmapping = "cfmigrations";
    this.autoMapModels = false;
    this.dependencies = [ "qb" ];

    function configure() {
        settings = {
            migrationsDirectory = "/resources/database/migrations",
            defaultGrammar = "BaseGrammar"
        };

        binder.map( "MigrationService@cfmigrations" )
            .to( "#moduleMapping#.models.MigrationService" )
            .initArg( name = "defaultGrammar", ref = "#settings.defaultGrammar#@qb" );
    }

}
