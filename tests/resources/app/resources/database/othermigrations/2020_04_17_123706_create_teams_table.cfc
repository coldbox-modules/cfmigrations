component {

    function up( schema, query ) {
        schema.create( "teams", function( table ) {
            table.increments( "id" );
            table.string( "name" ).unique();
            table.timestamp( "createdDate" ).default( "CURRENT_TIMESTAMP" );
        } );
    }

    function down( schema, query ) {
        schema.drop( "teams" );
    }

}
