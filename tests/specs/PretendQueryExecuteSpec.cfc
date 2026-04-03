/**
 * Tests that when pretend=true, a raw queryExecute() call inside a migration
 * CFC is intercepted by a WireBox-injected shim so that:
 *   1. The SQL is captured and surfaced (as a 4th arg to postProcessHook).
 *   2. Nothing is actually executed against the database.
 *
 * These tests are INTENTIONALLY FAILING until the injection mechanism is
 * implemented in QBMigrationManager.runMigration().
 *
 * Engines in scope: Lucee 5, Lucee 6 (and BoxLang in the future).
 */
component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

    property name="migrationService" inject="migrationService:default";
    property name="schema" inject="provider:SchemaBuilder@qb";
    property name="qb" inject="provider:QueryBuilder@qb";

    function beforeAll() {
        super.beforeAll();
        variables.migrationService.reset();
    }

    function run() {
        describe( "pretend mode with raw queryExecute migrations", function() {
            beforeEach( function() {
                variables.migrationService.setMigrationsDirectory( "/resources/database/pretendmigrations" );
                variables.migrationService.getManager().setMigrationsTable( "cfmigrations" );
                variables.migrationService.getManager().setDefaultGrammar( "PostgresGrammar@qb" );
            } );

            it( "captures SQL from queryExecute calls instead of running them when pretend=true", function() {
                variables.migrationService.install();

                var capturedQueryExecuteLog = [];

                /**
                 * When pretend=true the manager should:
                 *   a) Inject a queryExecute shim into the migration CFC via WireBox
                 *      so that raw queryExecute() calls are intercepted.
                 *   b) Pass the collected SQL log as a 4th argument to postProcessHook:
                 *      postProcessHook( migrationStruct, schema, query, queryExecuteLog )
                 */
                variables.migrationService.up(
                    pretend         = true,
                    postProcessHook = function( migrationStruct, schema, query, queryExecuteLog = [] ) {
                        capturedQueryExecuteLog.append( queryExecuteLog, true );
                    }
                );

                // The contacts table must NOT have been created — pretend means no execution.
                expect( schema.hasTable( "contacts" ) ).toBeFalse(
                    "contacts table should not exist when running in pretend mode"
                );

                // The migration should NOT be logged in cfmigrations when pretending.
                expect(
                    qb.setDefaultOptions( { datasource: "cfmigrations_testing" } )
                      .from( "cfmigrations" )
                      .count()
                ).toBe(
                    0,
                    "No migration should be recorded in the cfmigrations table when pretending"
                );

                // At least one SQL statement must have been captured from the raw
                // queryExecute calls in the migration's up() method.
                expect( capturedQueryExecuteLog ).toHaveLength(
                    1,
                    "One SQL statement should have been captured from the queryExecute call"
                );

                expect( capturedQueryExecuteLog[ 1 ] ).toInclude(
                    "CREATE TABLE",
                    "The captured SQL should contain the CREATE TABLE statement from the migration"
                );
            } );

        } );
    }

}
