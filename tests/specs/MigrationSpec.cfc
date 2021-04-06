component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	property name="migrationService" inject="MigrationService@cfmigrations";
	property name="schema"           inject="provider:SchemaBuilder@qb";
	property name="qb"               inject="provider:QueryBuilder@qb";

    function beforeAll() {
        super.beforeAll();
        variables.migrationService.reset();
    }

	function run() {
		describe( "cfmigrations", function() {
			beforeEach( function() {
				variables.migrationService.setMigrationsDirectory( "/resources/database/migrations" );
				variables.migrationService.setMigrationsTable( "cfmigrations" );
				variables.migrationService.setDefaultGrammar( "PostgresGrammar@qb" );
			} );

			it( "can install the migration table", function() {
				expect( schema.hasTable( "cfmigrations" ) ).toBeFalse( "cfmigrations table should not exist" );
				variables.migrationService.install();
				expect( schema.hasTable( "cfmigrations" ) ).toBeTrue( "cfmigrations table should exist" );
			} );

			it( "calling install multiple times does nothing if the migrations table is already installed", function() {
				expect( schema.hasTable( "cfmigrations" ) ).toBeFalse( "cfmigrations table should not exist" );
				variables.migrationService.install();
				expect( schema.hasTable( "cfmigrations" ) ).toBeTrue( "cfmigrations table should exist" );
				variables.migrationService.install();
				variables.migrationService.install();
				variables.migrationService.install();
			} );

			it( "can uninstall the migration table", function() {
				variables.migrationService.install();
				expect( schema.hasTable( "cfmigrations" ) ).toBeTrue( "cfmigrations table should exist" );
				variables.migrationService.uninstall();
				expect( schema.hasTable( "cfmigrations" ) ).toBeFalse( "cfmigrations table should not exist" );
			} );

			it( "can run all migrations up", function() {
				variables.migrationService.install();
				expect( schema.hasTable( "cfmigrations" ) ).toBeTrue( "cfmigrations table should exist" );
				variables.migrationService.up();
				expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
				expect( schema.hasTable( "posts" ) ).toBeTrue( "posts table should exist" );
				expect( qb.from( "cfmigrations" ).count() ).toBe( 2, "Two records should be in the cfmigrations table" );
			} );

			it( "can run one migration up", function() {
				variables.migrationService.install();
				expect( schema.hasTable( "cfmigrations" ) ).toBeTrue( "cfmigrations table should exist" );
				variables.migrationService.up( once = true );
				expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
				expect( schema.hasTable( "posts" ) ).toBeFalse( "posts table should not exist" );
				expect( qb.from( "cfmigrations" ).count() ).toBe( 1, "One record should be in the cfmigrations table" );
			} );

			it( "installs the migration table when migrating up", function() {
				variables.migrationService.up( once = true );
				expect( schema.hasTable( "cfmigrations" ) ).toBeTrue( "cfmigrations table should exist" );
				expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
				expect( qb.from( "cfmigrations" ).count() ).toBe( 1, "One record should be in the cfmigrations table" );
			} );

			it( "can run all migrations up when installing", function() {
				variables.migrationService.install( runAll = true );
				expect( schema.hasTable( "cfmigrations" ) ).toBeTrue( "cfmigrations table should exist" );
				expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
				expect( schema.hasTable( "posts" ) ).toBeTrue( "posts table should exist" );
				expect( qb.from( "cfmigrations" ).count() ).toBe( 2, "Two records should be in the cfmigrations table" );
			} );

			it( "can run all migrations down", function() {
				variables.migrationService.install( runAll = true );
				variables.migrationService.down();
				expect( schema.hasTable( "cfmigrations" ) ).toBeTrue( "cfmigrations table should exist" );
				expect( schema.hasTable( "users" ) ).toBeFalse( "users table should not exist" );
				expect( schema.hasTable( "posts" ) ).toBeFalse( "posts table should not exist" );
				expect( qb.from( "cfmigrations" ).count() ).toBe( 0, "No records should be in the cfmigrations table" );
			} );

			it( "can run one migration down", function() {
				variables.migrationService.install( runAll = true );
				expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
				expect( schema.hasTable( "posts" ) ).toBeTrue( "posts table should exist" );
				variables.migrationService.down( once = true );
				expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
				expect( schema.hasTable( "posts" ) ).toBeFalse( "posts table should not exist" );
				expect( schema.hasTable( "cfmigrations" ) ).toBeTrue( "cfmigrations table should exist" );
				expect( qb.from( "cfmigrations" ).count() ).toBe( 1, "One record should be in the cfmigrations table" );
			} );

			it( "runs all migrations down when uninstalling", function() {
				variables.migrationService.install( runAll = true );
				expect( schema.hasTable( "users" ) ).toBeTrue( "users table should exist" );
				expect( schema.hasTable( "posts" ) ).toBeTrue( "posts table should exist" );
				variables.migrationService.uninstall();
				expect( schema.hasTable( "users" ) ).toBeFalse( "users table should not exist" );
				expect( schema.hasTable( "posts" ) ).toBeFalse( "posts table should not exist" );
				expect( schema.hasTable( "cfmigrations" ) ).toBeFalse( "cfmigrations table should not exist" );
			} );

			it( "can customize the migrations directory", function() {
				variables.migrationService.setMigrationsDirectory( "/resources/database/othermigrations" );
				variables.migrationService.up();
				expect( schema.hasTable( "users" ) ).toBeFalse( "users table should not exist" );
				expect( schema.hasTable( "posts" ) ).toBeFalse( "posts table should not exist" );
				expect( schema.hasTable( "teams" ) ).toBeTrue( "posts table should exist" );
				expect( schema.hasTable( "cfmigrations" ) ).toBeTrue( "cfmigrations table should exist" );
				expect( qb.from( "cfmigrations" ).count() ).toBe( 1, "One record should be in the cfmigrations table" );
			} );

			it( "can customize the name of the cfmigrations table", function() {
				variables.migrationService.setMigrationsTable( "custom_cfmigrations_table" );
				variables.migrationService.install();
				expect( schema.hasTable( "cfmigrations" ) ).toBeFalse( "cfmigrations table should not exist" );
				expect( schema.hasTable( "custom_cfmigrations_table" ) ).toBeTrue(
					"custom_cfmigrations_table table should exist"
				);
			} );
		} );
	}

}
