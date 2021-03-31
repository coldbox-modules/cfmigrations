/**
 * Processes WireBox DSL's starting with "migrationService:"
 */
component {

    /**
     * Creates the Migration Service DSL Processor.
     *
     * @injector  The WireBox injector.
     *
     * @return    MigrationServiceDSL
     */
    public MigrationServiceDSL function init( required Injector injector ) {
        variables.injector = arguments.injector;
        return this;
    }

    /**
     * Creates a MigrationService from the dsl.
     * The portion after the colon is used to identifier the manager.
     *
     * @definition  The dsl struct definition.
     *
     * @return      MigrationService
     */
    public MigrationService function process( required struct definition ) {
        var settings = variables.injector.getInstance( dsl = "coldbox:moduleSettings:cfmigrations" );
        return variables.injector.getInstance(
            name = "MigrationService@cfmigrations",
            initArguments = settings.managers[ listRest( arguments.definition.dsl, ":" ) ]
        );
    }

}
