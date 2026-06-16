/**
 * Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
 * www.ortussolutions.com
 * ---
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
     * Process an incoming DSL definition and produce an object with it
     *
     * @definition   The injection dsl definition structure to process. Keys: name, dsl
     * @targetObject The target object we are building the DSL dependency for. If empty, means we are just requesting building
     * @targetID     The target ID we are building this dependency for
     *
     * @return coldbox.system.ioc.dsl.IDSLBuilder
     */
    function process( required definition, targetObject, targetID ) {
        var settings = variables.injector.getInstance( dsl = "coldbox:moduleSettings:cbMigrations" );
        return variables.injector.getInstance(
            name = "MigrationService@cbMigrations",
            initArguments = settings.managers[ listRest( arguments.definition.dsl, ":" ) ]
        );
    }

}
