component {

	function run( schema, query ) {
		var mockData = new testbox.system.modules.mockdatacfc.models.MockData();

		var testUsers = mockData.mock(
			argumentCollection = {
				"$num"     : 20,
				"email"    : "email",
				"password" : "word"
			}
		);

		query.table( "users" ).insert( testUsers );
	}

}
