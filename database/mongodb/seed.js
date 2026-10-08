use("smartmove_db");

// These demo references are placeholders. Replace their Oracle IDs before testing
// cross-database joins against records in your own Oracle schema.
db.vehicle_content.updateOne(
  { demo_key: "smartmove-coursework-vehicle" },
  {
    $setOnInsert: {
      demo_key: "smartmove-coursework-vehicle",
      vehicle_id: 900001,
      registration_number: "DEMO-9001",
      vehicle_type: "Bus",
      documents: [
        {
          document_type: "Insurance",
          document_number: "DEMO-INS-9001",
          expiry_date: ISODate("2027-12-31T00:00:00Z"),
          status: "valid"
        }
      ],
      images: [
        {
          image_url: "https://example.invalid/smartmove/demo-bus.jpg",
          caption: "Demonstration bus",
          tags: ["exterior"],
          uploaded_at: new Date()
        }
      ],
      metadata: { source: "coursework demo" },
      updated_at: new Date()
    }
  },
  { upsert: true }
);

db.passenger_feedback.updateOne(
  { demo_key: "smartmove-coursework-feedback" },
  {
    $setOnInsert: {
      demo_key: "smartmove-coursework-feedback",
      passenger_id: 900001,
      route_id: 900001,
      trip_id: 900001,
      vehicle_id: 900001,
      driver_id: 900001,
      rating: 5,
      category: "compliment",
      comment: "The demonstration trip was comfortable and punctual.",
      tags: ["comfortable", "punctual"],
      replies: [],
      posted_at: new Date()
    }
  },
  { upsert: true }
);

db.passenger_feedback.updateOne(
  { demo_key: "smartmove-coursework-complaint" },
  {
    $setOnInsert: {
      demo_key: "smartmove-coursework-complaint",
      passenger_id: 900002,
      route_id: 900001,
      trip_id: 900002,
      vehicle_id: 900001,
      driver_id: 900001,
      rating: 2,
      category: "complaint",
      comment: "The demonstration bus was delayed at the departure point.",
      tags: ["delay"],
      replies: [],
      posted_at: new Date()
    }
  },
  { upsert: true }
);

db.travel_announcements.updateOne(
  { demo_key: "smartmove-coursework-announcement" },
  {
    $setOnInsert: {
      demo_key: "smartmove-coursework-announcement",
      title: "Demonstration route notice",
      message: "This is a sample SmartMove travel announcement.",
      type: "service_update",
      target_route_ids: [900001],
      audience: "passengers",
      active: true,
      published_at: new Date()
    }
  },
  { upsert: true }
);

db.user_notifications.updateOne(
  { demo_key: "smartmove-coursework-notification" },
  {
    $setOnInsert: {
      demo_key: "smartmove-coursework-notification",
      recipient_id: 900001,
      title: "Your demonstration trip is scheduled",
      message: "This sample notification demonstrates trip updates for a passenger.",
      type: "trip_update",
      read: false,
      created_at: new Date()
    }
  },
  { upsert: true }
);

db.community_posts.updateOne(
  { demo_key: "smartmove-coursework-discussion" },
  {
    $setOnInsert: {
      demo_key: "smartmove-coursework-discussion",
      author_name: "SmartMove Instructor",
      author_role: "instructor",
      topic: "Travel feedback and service improvement",
      message: "Use this discussion to share constructive suggestions about the transport service.",
      replies: [],
      posted_at: new Date()
    }
  },
  { upsert: true }
);

db.passenger_feedback.createIndex({ route_id: 1, posted_at: -1 });
db.passenger_feedback.createIndex({ category: 1, posted_at: -1 });
db.vehicle_content.createIndex({ vehicle_id: 1 }, { unique: true });
db.travel_announcements.createIndex({ active: 1, published_at: -1 });
db.user_notifications.createIndex({ recipient_id: 1, created_at: -1 });
db.community_posts.createIndex({ posted_at: -1 });
