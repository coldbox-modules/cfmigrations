component extends="tests.resources.ModuleIntegrationSpec" {

    property name="migrationService" inject="migrationService:default";
    property name="schema" inject="provider:SchemaBuilder@qb";
    property name="qb" inject="provider:QueryBuilder@qb";

    function beforeAll() {
        super.beforeAll();
        variables.migrationService.reset();
    }

    function run() {

        describe( "Migrations", function() {
            beforeEach( function() {
                variables.migrationService.setMigrationsDirectory( "/resources/database/migrations" );
                variables.migrationService.getManager().setMigrationsTable( "cbmigrations" );
                variables.migrationService.getManager().setDefaultGrammar( "PostgresGrammar@qb" );
                variables.migrationService.setSeedEnvironments( [ "development" ] );
            } );

            it( "can install the migration table", function() {
                expect( schema.hasTable( "cbmigrations" ) ).toBeFalse( "cbmigrations table should not exist" );
                variables.migrationService.install();
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
            } );

            it( "renames a legacy cfmigrations table to the new default name, preserving its data", function() {
                schema.create( "cfmigrations", function( table ) {
                    table.string( "name", 190 ).primaryKey();
                    table.datetime( "migration_ran" );
                } );
                qb.from( "cfmigrations" ).insert( { "name": "001_CreateUsersTable", "migration_ran": now() } );

                variables.migrationService.install();

                expect( schema.hasTable( "cfmigrations" ) ).toBeFalse( "legacy cfmigrations table should be renamed away" );
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
                expect( qb.from( "cbmigrations" ).count() ).toBe( 1, "legacy migration history should be preserved" );
            } );

            it( "calling install multiple times does nothing if the migrations table is already installed", function() {
                expect( schema.hasTable( "cbmigrations" ) ).toBeFalse( "cbmigrations table should not exist" );
                variables.migrationService.install();
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
                variables.migrationService.install();
                variables.migrationService.install();
                variables.migrationService.install();
            } );

            it( "can uninstall the migration table", function() {
                variables.migrationService.install();
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
                variables.migrationService.uninstall();
                expect( schema.hasTable( "cbmigrations" ) ).toBeFalse( "cbmigrations table should not exist" );
            } );

            it( "can run all migrations up", function() {
                variables.migrationService.install();
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
                variables.migrationService.up();
                expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
                expect( schema.hasTable( "posts" ) ).toBeTrue( "posts table should exist" );
                expect( qb.from( "cbmigrations" ).count() ).toBe( 2, "Two records should be in the cbmigrations table" );
            } );

            it( "can run one migration up", function() {
                variables.migrationService.install();
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
                variables.migrationService.up( once = true );
                expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
                expect( schema.hasTable( "posts" ) ).toBeFalse( "posts table should not exist" );
                expect( qb.from( "cbmigrations" ).count() ).toBe( 1, "One record should be in the cbmigrations table" );
            } );

            it( "installs the migration table when migrating up", function() {
                variables.migrationService.up( once = true );
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
                expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
                expect( qb.from( "cbmigrations" ).count() ).toBe( 1, "One record should be in the cbmigrations table" );
            } );

            it( "can run all migrations up when installing", function() {
                variables.migrationService.install( runAll = true );
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
                expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
                expect( schema.hasTable( "posts" ) ).toBeTrue( "posts table should exist" );
                expect( qb.from( "cbmigrations" ).count() ).toBe( 2, "Two records should be in the cbmigrations table" );
            } );

            it( "can run all migrations down", function() {
                variables.migrationService.install( runAll = true );
                variables.migrationService.down();
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
                expect( schema.hasTable( "users" ) ).toBeFalse( "users table should not exist" );
                expect( schema.hasTable( "posts" ) ).toBeFalse( "posts table should not exist" );
                expect( qb.from( "cbmigrations" ).count() ).toBe( 0, "No records should be in the cbmigrations table" );
            } );

            it( "can run one migration down", function() {
                variables.migrationService.install( runAll = true );
                expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
                expect( schema.hasTable( "posts" ) ).toBeTrue( "posts table should exist" );
                variables.migrationService.down( once = true );
                expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
                expect( schema.hasTable( "posts" ) ).toBeFalse( "posts table should not exist" );
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
                expect( qb.from( "cbmigrations" ).count() ).toBe( 1, "One record should be in the cbmigrations table" );
            } );

            it( "runs all migrations down when uninstalling", function() {
                variables.migrationService.install( runAll = true );
                expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
                expect( schema.hasTable( "posts" ) ).toBeTrue( "posts table should exist" );
                variables.migrationService.uninstall();
                expect( schema.hasTable( "users" ) ).toBeFalse( "users table should not exist" );
                expect( schema.hasTable( "posts" ) ).toBeFalse( "posts table should not exist" );
                expect( schema.hasTable( "cbmigrations" ) ).toBeFalse( "cbmigrations table should not exist" );
            } );

            it( "can customize the migrations directory", function() {
                variables.migrationService.setMigrationsDirectory( "/resources/database/othermigrations" );
                variables.migrationService.up();
                expect( schema.hasTable( "users" ) ).toBeFalse( "users table should not exist" );
                expect( schema.hasTable( "posts" ) ).toBeFalse( "posts table should not exist" );
                expect( schema.hasTable( "teams" ) ).toBeTrue( "posts table should exist" );
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
                expect( qb.from( "cbmigrations" ).count() ).toBe( 1, "One record should be in the cbmigrations table" );
            } );

            it( "can customize the name of the cbmigrations table", function() {
                variables.migrationService.getManager().setMigrationsTable( "custom_cbmigrations_table" );
                variables.migrationService.install();
                expect( schema.hasTable( "cbmigrations" ) ).toBeFalse( "cbmigrations table should not exist" );
                expect( schema.hasTable( "custom_cbmigrations_table" ) ).toBeTrue(
                    "custom_cbmigrations_table table should exist"
                );
            } );

            it( "can pass a seed argument which the seeder data migrations", function() {
                variables.migrationService.install();
                expect( schema.hasTable( "cbmigrations" ) ).toBeTrue( "cbmigrations table should exist" );
                variables.migrationService.up( seed = true );
                expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
                expect( qb.from( "users" ).count() ).toBe( 20, "The seeder data was not inserted" );
            } );

            it( "Will throw an error if attempting to run seeds in an unauthorized environment", function() {
                variables.migrationService.setSeedEnvironments( [ "foo" ] );
                expect( function() {
                    variables.migrationService.seed();
                } ).toThrow();
            } );
        } );
    }

}
