component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

    function run() {
        describe( "MigrationService", function() {
            it( "can instantiate with a default migration manager", function() {
                var migrationService = application.wirebox.getInstance( "migrationService:default" );
                expect( migrationService.getMigrationsDirectory() ).toBe( "/resources/database/migrations" );
                expect( migrationService.getSeedsDirectory() ).toBe( "/resources/database/seeds" );
                var manager = migrationService.getManager();
                expect( manager.getDefaultGrammar() ).toBe( "AutoDiscover@qb" );
                expect( manager.getDatasource() ).toBeNull();
                expect( manager.getMigrationsTable() ).toBe( "cfmigrations" );
                expect( manager.getSchema() ).toBe( "" );
                expect( manager.getUseTransactions() ).toBeTrue();
            } );

            it( "can instantiate with different named migration managers", function() {
                var migrationService = application.wirebox.getInstance( "migrationService:db1" );
                expect( migrationService.getMigrationsDirectory() ).toBe( "/resources/database/db1/migrations" );
                expect( migrationService.getSeedsDirectory() ).toBe( "/resources/database/db1/seeds" );
                var manager = migrationService.getManager();
                expect( manager.getDefaultGrammar() ).toBe( "MySQLGrammar@qb" );
                expect( manager.getDatasource() ).notToBeNull();
                expect( manager.getDatasource() ).toBe( "db1" );
                expect( manager.getMigrationsTable() ).toBe( "cfmigrations" );
                expect( manager.getUseTransactions() ).toBeFalse();
            } );
        } );
    }

}
