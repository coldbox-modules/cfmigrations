component {

    this.name = "cfmigrations"
    this.author = "Eric Peterson"
    this.description = "Keep track and run your database migrations and seeders."
    this.version = "0.0.0"
    this.cfmapping = "cfmigrations"
    this.dependencies = [ "qb", "cbMockData" ]

    function configure() {
        variables.settings = {
            "managers": {
                "default": {
                    "manager": "cfmigrations.models.QBMigrationManager",
                    "properties": { "defaultGrammar": "AutoDiscover@qb" }
                }
            }
        }

        binder.getInjector().registerDSL( "migrationService", "#moduleMapping#.dsl.MigrationServiceDSL" )
    }

}
