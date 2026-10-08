package lk.smartmove.mongo;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import com.mongodb.client.gridfs.GridFSBucket;
import com.mongodb.client.gridfs.model.GridFSFile;
import com.mongodb.client.gridfs.model.GridFSUploadOptions;
import com.mongodb.client.model.ReplaceOptions;
import com.mongodb.client.model.UpdateOptions;
import com.mongodb.client.model.Updates;
import org.bson.BsonObjectId;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Locale;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import java.util.Set;

import static com.mongodb.client.model.Filters.*;
import static com.mongodb.client.model.Sorts.descending;

@RestController
@RequestMapping("/api/mongo")
public class TransportContentController {
    private static final String VEHICLE_CONTENT = "vehicle_content";
    private static final String PASSENGER_FEEDBACK = "passenger_feedback";
    private static final String TRAVEL_ANNOUNCEMENTS = "travel_announcements";
    private static final String USER_NOTIFICATIONS = "user_notifications";
    private static final String COMMUNITY_POSTS = "community_posts";
    private static final long MAX_VEHICLE_IMAGE_BYTES = 8L * 1024 * 1024;
    private static final Set<String> VEHICLE_IMAGE_TYPES = Set.of(
            "image/jpeg", "image/png", "image/webp", "image/gif");

    private final MongoDatabase database;
    private final GridFSBucket gridFsBucket;

    public TransportContentController(MongoClient client,
                                      GridFSBucket gridFsBucket,
                                      @Value("${smartmove.mongodb.database}") String databaseName) {
        this.database = client.getDatabase(databaseName);
        this.gridFsBucket = gridFsBucket;
    }

    @GetMapping("/vehicle-content")
    public List<Document> vehicleContent() {
        return read(collection(VEHICLE_CONTENT).find().sort(descending("updated_at")).limit(500));
    }

    @GetMapping("/vehicle-content/{vehicleId}")
    public Document vehicleContent(@PathVariable String vehicleId) {
        Document result = collection(VEHICLE_CONTENT).find(eq("vehicle_id", parseId(vehicleId, "vehicleId"))).first();
        if (result == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Vehicle content not found");
        }
        return normalize(result);
    }

    @PostMapping(value = "/vehicle-content/{vehicleId}/image", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> uploadVehicleImage(@PathVariable String vehicleId,
                                                  @RequestParam String registrationNumber,
                                                  @RequestParam String vehicleType,
                                                  @RequestPart("image") MultipartFile image) throws IOException {
        long oracleVehicleId = ((Number) parseId(vehicleId, "vehicleId")).longValue();
        if (registrationNumber.isBlank() || vehicleType.isBlank()) {
            throw badRequest("Registration number and vehicle type are required");
        }
        if (image.isEmpty()) {
            throw badRequest("Select a non-empty vehicle image");
        }
        if (image.getSize() > MAX_VEHICLE_IMAGE_BYTES) {
            throw badRequest("Vehicle image must be 8 MB or smaller");
        }
        String contentType = image.getContentType();
        if (contentType == null || !VEHICLE_IMAGE_TYPES.contains(contentType.toLowerCase(Locale.ROOT))) {
            throw badRequest("Vehicle image must be a JPEG, PNG, WebP, or GIF file");
        }

        String extension = switch (contentType.toLowerCase(Locale.ROOT)) {
            case "image/jpeg" -> ".jpg";
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            case "image/gif" -> ".gif";
            default -> throw badRequest("Unsupported vehicle image format");
        };
        ObjectId imageId = new ObjectId();
        String filename = "vehicle-" + oracleVehicleId + "-" + imageId + extension;
        Document metadata = new Document("contentType", contentType.toLowerCase(Locale.ROOT))
                .append("vehicleId", oracleVehicleId);
        try (var input = image.getInputStream()) {
            gridFsBucket.uploadFromStream(new BsonObjectId(imageId), filename, input,
                    new GridFSUploadOptions().metadata(metadata));
        }

        Date uploadedAt = new Date();
        Document imageRecord = new Document("image_id", imageId.toHexString())
                .append("image_url", "/api/mongo/vehicle-content/images/" + imageId.toHexString())
                .append("file_name", filename)
                .append("content_type", contentType.toLowerCase(Locale.ROOT))
                .append("size_bytes", image.getSize())
                .append("uploaded_at", uploadedAt);
        collection(VEHICLE_CONTENT).updateOne(eq("vehicle_id", oracleVehicleId),
                Updates.combine(
                        Updates.setOnInsert("vehicle_id", oracleVehicleId),
                        Updates.setOnInsert("registration_number", registrationNumber),
                        Updates.setOnInsert("vehicle_type", vehicleType),
                        Updates.setOnInsert("documents", List.of()),
                        Updates.push("images", imageRecord),
                        Updates.set("updated_at", uploadedAt)),
                new UpdateOptions().upsert(true));
        return Map.of("uploaded", true, "vehicle_id", oracleVehicleId,
                "image_id", imageId.toHexString(), "image_url", imageRecord.getString("image_url"));
    }

    @GetMapping("/vehicle-content/images/{imageId}")
    public ResponseEntity<byte[]> vehicleImage(@PathVariable String imageId) throws IOException {
        ObjectId id = parseObjectId(imageId);
        GridFSFile file = gridFsBucket.find(eq("_id", id)).first();
        if (file == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Vehicle image not found");
        }
        Document metadata = file.getMetadata();
        String contentType = metadata == null ? null : metadata.getString("contentType");
        MediaType mediaType;
        try {
            mediaType = contentType == null ? MediaType.APPLICATION_OCTET_STREAM : MediaType.parseMediaType(contentType);
        } catch (IllegalArgumentException exception) {
            mediaType = MediaType.APPLICATION_OCTET_STREAM;
        }
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        gridFsBucket.downloadToStream(id, output);
        return ResponseEntity.ok()
                .contentType(mediaType)
                .contentLength(output.size())
                .cacheControl(CacheControl.noCache())
                .body(output.toByteArray());
    }

    @PutMapping("/vehicle-content/{vehicleId}")
    public Map<String, Object> saveVehicleContent(@PathVariable String vehicleId,
                                                  @RequestBody Map<String, Object> body) {
        rejectMongoId(body);
        Object id = parseId(vehicleId, "vehicleId");
        Object submittedId = body.get("vehicle_id");
        if (submittedId != null && !id.equals(parseId(submittedId.toString(), "vehicle_id"))) {
            throw badRequest("vehicle_id in the document must match the URL");
        }
        requireText(body, "registration_number");
        requireText(body, "vehicle_type");
        requireList(body, "documents");
        requireList(body, "images");

        Document content = new Document(body);
        content.put("vehicle_id", id);
        content.put("updated_at", new Date());
        collection(VEHICLE_CONTENT).replaceOne(eq("vehicle_id", id), content,
                new ReplaceOptions().upsert(true));
        return Map.of("saved", true, "vehicle_id", id);
    }

    @GetMapping("/feedback")
    public List<Document> feedback(@RequestParam(required = false) String routeId) {
        MongoCollection<Document> collection = collection(PASSENGER_FEEDBACK);
        var query = routeId == null || routeId.isBlank()
                ? new Document()
                : eq("route_id", parseId(routeId, "routeId"));
        return read(collection.find(query).sort(descending("posted_at")).limit(500));
    }

    @PostMapping("/feedback")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> createFeedback(@RequestBody Map<String, Object> body) {
        rejectMongoId(body);
        requireOracleId(body, "passenger_id");
        requireOracleId(body, "route_id");
        for (String field : List.of("trip_id", "vehicle_id", "driver_id")) {
            if (body.containsKey(field)) {
                requireOracleId(body, field);
            }
        }
        requireNumeric(body, "rating");
        requireText(body, "category");
        requireText(body, "comment");
        if (body.containsKey("tags") && !(body.get("tags") instanceof List<?>)) {
            throw badRequest("tags must be an array");
        }
        int rating = ((Number) body.get("rating")).intValue();
        if (rating < 1 || rating > 5 || ((Number) body.get("rating")).doubleValue() != rating) {
            throw badRequest("rating must be a whole number from 1 to 5");
        }
        if (!List.of("compliment", "complaint", "suggestion").contains(body.get("category").toString())) {
            throw badRequest("category must be compliment, complaint, or suggestion");
        }
        Document feedback = new Document(body);
        feedback.put("replies", new ArrayList<>());
        feedback.put("posted_at", new Date());
        collection(PASSENGER_FEEDBACK).insertOne(feedback);
        return Map.of("created", true, "id", feedback.getObjectId("_id").toHexString());
    }

    @GetMapping("/ratings/vehicles")
    public List<Document> vehicleRatings() {
        return ratings("vehicle_id");
    }

    @GetMapping("/ratings/drivers")
    public List<Document> driverRatings() {
        return ratings("driver_id");
    }

    @GetMapping("/complaints")
    public List<Document> complaints(@RequestParam String keyword) {
        if (keyword.isBlank() || keyword.length() > 100) {
            throw badRequest("keyword must contain 1 to 100 characters");
        }
        Pattern literalKeyword = Pattern.compile(Pattern.quote(keyword), Pattern.CASE_INSENSITIVE);
        return read(collection(PASSENGER_FEEDBACK).find(and(
                eq("category", "complaint"), regex("comment", literalKeyword)))
                .sort(descending("posted_at")).limit(500));
    }

    @PostMapping("/feedback/{feedbackId}/replies")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> replyToFeedback(@PathVariable String feedbackId,
                                               @RequestBody Map<String, Object> body) {
        requireText(body, "author_name");
        requireText(body, "author_role");
        requireText(body, "message");
        Document reply = new Document("author_name", body.get("author_name"))
                .append("author_role", body.get("author_role"))
                .append("message", body.get("message"))
                .append("posted_at", new Date());
        var result = collection(PASSENGER_FEEDBACK).updateOne(
                objectIdFilter(feedbackId), new Document("$push", new Document("replies", reply)));
        requireMatched(result.getMatchedCount(), "Feedback entry not found");
        return Map.of("created", true);
    }

    @GetMapping("/announcements")
    public List<Document> announcements(@RequestParam(defaultValue = "true") boolean activeOnly) {
        MongoCollection<Document> collection = collection(TRAVEL_ANNOUNCEMENTS);
        return read((activeOnly ? collection.find(eq("active", true)) : collection.find())
                .sort(descending("published_at")).limit(500));
    }

    @PostMapping("/announcements")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> createAnnouncement(@RequestBody Map<String, Object> body) {
        rejectMongoId(body);
        requireText(body, "title");
        requireText(body, "message");
        requireText(body, "type");
        Document announcement = new Document(body);
        announcement.putIfAbsent("active", true);
        announcement.put("published_at", new Date());
        collection(TRAVEL_ANNOUNCEMENTS).insertOne(announcement);
        return Map.of("created", true, "id", announcement.getObjectId("_id").toHexString());
    }

    @PatchMapping("/announcements/{announcementId}/active")
    public Map<String, Object> setAnnouncementStatus(@PathVariable String announcementId,
                                                     @RequestBody Map<String, Object> body) {
        if (!(body.get("active") instanceof Boolean active)) {
            throw badRequest("active must be true or false");
        }
        var result = collection(TRAVEL_ANNOUNCEMENTS).updateOne(
                objectIdFilter(announcementId), new Document("$set", new Document("active", active)));
        requireMatched(result.getMatchedCount(), "Announcement not found");
        return Map.of("updated", true);
    }

    @GetMapping("/notifications")
    public List<Document> notifications(@RequestParam(required = false) String recipientId) {
        MongoCollection<Document> collection = collection(USER_NOTIFICATIONS);
        var query = recipientId == null || recipientId.isBlank()
                ? new Document()
                : eq("recipient_id", parseId(recipientId, "recipientId"));
        return read(collection.find(query).sort(descending("created_at")).limit(500));
    }

    @PostMapping("/notifications")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> createNotification(@RequestBody Map<String, Object> body) {
        rejectMongoId(body);
        requireText(body, "title");
        requireText(body, "message");
        requireText(body, "type");
        if (body.containsKey("recipient_id")) {
            requireOracleId(body, "recipient_id");
        }
        Document notification = new Document(body);
        notification.put("read", false);
        notification.put("created_at", new Date());
        collection(USER_NOTIFICATIONS).insertOne(notification);
        return Map.of("created", true, "id", notification.getObjectId("_id").toHexString());
    }

    @PatchMapping("/notifications/{notificationId}/read")
    public Map<String, Object> markNotificationRead(@PathVariable String notificationId) {
        var result = collection(USER_NOTIFICATIONS).updateOne(objectIdFilter(notificationId),
                new Document("$set", new Document("read", true).append("read_at", new Date())));
        requireMatched(result.getMatchedCount(), "Notification not found");
        return Map.of("updated", true);
    }

    @GetMapping("/community")
    public List<Document> communityPosts() {
        return read(collection(COMMUNITY_POSTS).find().sort(descending("posted_at")).limit(500));
    }

    @PostMapping("/community")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> createCommunityPost(@RequestBody Map<String, Object> body) {
        rejectMongoId(body);
        requireText(body, "author_name");
        String authorRole = requireCommunityRole(body);
        requireText(body, "topic");
        requireText(body, "message");
        Document post = new Document(body);
        post.put("author_role", authorRole);
        post.put("replies", new ArrayList<>());
        post.put("posted_at", new Date());
        collection(COMMUNITY_POSTS).insertOne(post);
        return Map.of("created", true, "id", post.getObjectId("_id").toHexString());
    }

    @PostMapping("/community/{postId}/replies")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> replyToCommunityPost(@PathVariable String postId,
                                                   @RequestBody Map<String, Object> body) {
        requireText(body, "author_name");
        String authorRole = requireCommunityRole(body);
        requireText(body, "message");
        Document reply = new Document("author_name", body.get("author_name"))
                .append("author_role", authorRole)
                .append("message", body.get("message"))
                .append("posted_at", new Date());
        var result = collection(COMMUNITY_POSTS).updateOne(
                objectIdFilter(postId), new Document("$push", new Document("replies", reply)));
        requireMatched(result.getMatchedCount(), "Discussion post not found");
        return Map.of("created", true);
    }

    private List<Document> ratings(String entityField) {
        List<Document> pipeline = List.of(
                new Document("$match", new Document(entityField, new Document("$exists", true))
                        .append("rating", new Document("$type", "number"))),
                new Document("$group", new Document("_id", "$" + entityField)
                        .append("average_rating", new Document("$avg", "$rating"))
                        .append("review_count", new Document("$sum", 1))),
                new Document("$sort", new Document("average_rating", -1))
        );
        return read(collection(PASSENGER_FEEDBACK).aggregate(pipeline));
    }

    private MongoCollection<Document> collection(String name) {
        return database.getCollection(name);
    }

    private static List<Document> read(Iterable<Document> source) {
        List<Document> result = new ArrayList<>();
        for (Document document : source) {
            result.add(normalize(document));
        }
        return result;
    }

    private static Document normalize(Document source) {
        Document result = new Document(source);
        Object id = result.get("_id");
        if (id instanceof ObjectId objectId) {
            result.put("_id", objectId.toHexString());
        }
        return result;
    }

    private static Object parseId(String value, String field) {
        try {
            long id = Long.parseLong(value);
            if (id <= 0) {
                throw badRequest(field + " must be a positive Oracle ID");
            }
            return id;
        } catch (NumberFormatException exception) {
            throw badRequest(field + " must be a numeric Oracle ID");
        }
    }

    private static void requireText(Map<String, Object> body, String field) {
        if (!(body.get(field) instanceof String value) || value.isBlank()) {
            throw badRequest(field + " is required");
        }
    }

    private static void requireNumeric(Map<String, Object> body, String field) {
        if (!(body.get(field) instanceof Number)) {
            throw badRequest(field + " must be numeric");
        }
    }

    private static void requireOracleId(Map<String, Object> body, String field) {
        requireNumeric(body, field);
        Number id = (Number) body.get(field);
        if (id.longValue() <= 0 || id.doubleValue() != id.longValue()) {
            throw badRequest(field + " must be a positive whole-number Oracle ID");
        }
    }

    private static String requireCommunityRole(Map<String, Object> body) {
        requireText(body, "author_role");
        String role = body.get("author_role").toString().trim().toLowerCase();
        if (!List.of("student", "instructor").contains(role)) {
            throw badRequest("author_role must be student or instructor");
        }
        return role;
    }

    private static void requireList(Map<String, Object> body, String field) {
        if (!(body.get(field) instanceof List<?>)) {
            throw badRequest(field + " must be an array");
        }
    }

    private static void rejectMongoId(Map<String, Object> body) {
        if (body.containsKey("_id")) {
            throw badRequest("_id is managed by MongoDB");
        }
    }

    private static org.springframework.web.server.ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }

    private static void requireMatched(long count, String message) {
        if (count == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, message);
        }
    }

    private static org.bson.conversions.Bson objectIdFilter(String id) {
        return eq("_id", parseObjectId(id));
    }

    private static ObjectId parseObjectId(String id) {
        try {
            return new ObjectId(id);
        } catch (IllegalArgumentException exception) {
            throw badRequest("Invalid MongoDB document ID");
        }
    }
}
