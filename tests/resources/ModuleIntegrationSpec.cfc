component extends="coldbox.system.testing.BaseTestCase" {

	function beforeAll() {
		super.beforeAll();

		getController().getModuleService().registerAndActivateModule( "cfmigrations", "testingModuleRoot" );
		getWireBox().autowire( this );
	}

	function getInstance() {
		return getWireBox().getInstance( argumentCollection = arguments );
	}

	/**
	 * @beforeEach
	 */
	function setupIntegrationTest() {
		setup();
	}

	/**
	 * @aroundEach
	 */
	function useDatabaseTransactions( spec ) {
		transaction action="begin" {
			try {
				arguments.spec.body();
			} catch ( any e ) {
				rethrow;
			} finally {
				transaction action="rollback";
			}
		}
	}

}
