component {

    function up( schema, query ) {
        schema.create( "users", function( table ) {
            table.increments( "id" );
            table.string( "email" ).unique();
            table.string( "password" );
            table.timestamp( "createdDate" ).default( "CURRENT_TIMESTAMP" );
        } );
    }

    function down( schema, query ) {
        schema.drop( "users" );
    }

}
