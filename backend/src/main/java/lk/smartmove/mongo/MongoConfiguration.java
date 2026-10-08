package lk.smartmove.mongo;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.gridfs.GridFSBucket;
import com.mongodb.client.gridfs.GridFSBuckets;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MongoConfiguration {
    @Bean
    MongoClient mongoClient(@Value("${spring.data.mongodb.uri}") String uri) {
        return MongoClients.create(uri);
    }

    @Bean
    GridFSBucket gridFsBucket(MongoClient client,
                              @Value("${smartmove.mongodb.database}") String databaseName) {
        return GridFSBuckets.create(client.getDatabase(databaseName));
    }
}
