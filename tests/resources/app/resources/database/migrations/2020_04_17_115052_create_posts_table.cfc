component {

    function up( schema, query ) {
        schema.create( "posts", function( table ) {
            table.increments( "id" );
            table.string( "title" );
            table.text( "body" );
            table.unsignedInteger( "userId" ).references( "id" ).onTable( "users" );
            table.timestamp( "createdDate" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "modifiedDate" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "publishedDate" ).nullable();
        } );
    }

    function down( schema, query ) {
        schema.drop( "posts" );
    }

}
