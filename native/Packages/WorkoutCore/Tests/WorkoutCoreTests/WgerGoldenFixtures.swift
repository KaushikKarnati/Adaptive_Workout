// Pinned legacy source fixtures; provenance retained in native/ReferenceFixtures/wger.
enum WgerGoldenFixtures {
  static let pinned = #"""
    {
      "categories": [{"id":8,"name":"Arms"},{"id":9,"name":"Legs"},{"id":10,"name":"Abs"},{"id":11,"name":"Chest"},{"id":12,"name":"Back"},{"id":13,"name":"Shoulders"},{"id":14,"name":"Calves"},{"id":15,"name":"Cardio"}],
      "muscles": [{"id":1,"name":"Biceps brachii"},{"id":2,"name":"Anterior deltoid"},{"id":3,"name":"Serratus anterior"},{"id":4,"name":"Pectoralis major"},{"id":5,"name":"Triceps brachii"},{"id":6,"name":"Rectus abdominis"},{"id":7,"name":"Gastrocnemius"},{"id":8,"name":"Gluteus maximus"},{"id":9,"name":"Trapezius"},{"id":10,"name":"Quadriceps femoris"},{"id":11,"name":"Biceps femoris"},{"id":12,"name":"Latissimus dorsi"},{"id":13,"name":"Brachialis"},{"id":14,"name":"Obliquus externus abdominis"},{"id":15,"name":"Soleus"}],
      "equipment": [{"id":1,"name":"Barbell"},{"id":2,"name":"SZ-Bar"},{"id":3,"name":"Dumbbell"},{"id":4,"name":"Gym mat"},{"id":5,"name":"Swiss Ball"},{"id":6,"name":"Pull-up bar"},{"id":7,"name":"none (bodyweight exercise)"},{"id":8,"name":"Bench"},{"id":9,"name":"Incline bench"},{"id":10,"name":"Kettlebell"},{"id":11,"name":"Resistance band"},{"id":12,"name":"Cable machine"}],
      "licenses": [{"id":1,"name":"CC-BY-SA 3"},{"id":2,"name":"CC-BY-SA 4"},{"id":3,"name":"CC0"},{"id":4,"name":"CC-BY 4"},{"id":5,"name":"ODbL"}],
      "languages": [{"id":2,"short_name":"en"}],
      "exercises": [
        {
          "id":101,"uuid":"123e4567-e89b-42d3-a456-426614174000","category":{"id":11,"name":"Chest"},
          "muscles":[{"id":4,"name":"Pectoralis major"}],"muscles_secondary":[{"id":5,"name":"Triceps brachii"}],
          "equipment":[{"id":1,"name":"Barbell"},{"id":8,"name":"Bench"}],"license":{"id":2,"name":"CC-BY-SA 4"},
          "license_author":"Fixture Author","license_title":"Fixture base","last_update_global":"2026-09-06T10:20:30Z",
          "translations":[{"id":201,"uuid":"223e4567-e89b-42d3-a456-426614174000","language":{"id":2},"name":"Fixture bench press","description_source":"Lower the bar under control.","description":"<p>Ignored rendered HTML</p>","aliases":[{"alias":"Fixture press"}],"notes":["Ignored note"],"license":{"id":2,"name":"CC-BY-SA 4"},"license_author":"Fixture Translator","license_title":"Fixture bench press"}]
        },
        {
          "id":102,"uuid":"323e4567-e89b-42d3-a456-426614174000","category":{"id":11,"name":"Chest"},
          "muscles":[{"id":3,"name":"Serratus anterior"}],"muscles_secondary":[],"equipment":[],"license":{"id":3,"name":"CC0"},
          "license_author":null,"license_title":"Unsupported muscle fixture","last_update_global":null,
          "translations":[{"id":202,"uuid":"423e4567-e89b-42d3-a456-426614174000","language":{"id":2},"name":"Unsupported fixture","description_source":"Fixture instructions.","aliases":[],"notes":[],"license":{"id":3,"name":"CC0"},"license_author":null,"license_title":"Unsupported fixture"}]
        }
      ]
    }
    """#
  static let benchmark = #"""
    {
      "categories": [{"id":8,"name":"Arms"},{"id":9,"name":"Legs"},{"id":10,"name":"Abs"},{"id":11,"name":"Chest"},{"id":12,"name":"Back"},{"id":13,"name":"Shoulders"},{"id":14,"name":"Calves"},{"id":15,"name":"Cardio"}],
      "muscles": [{"id":1,"name":"Biceps brachii"},{"id":2,"name":"Anterior deltoid"},{"id":3,"name":"Serratus anterior"},{"id":4,"name":"Pectoralis major"},{"id":5,"name":"Triceps brachii"},{"id":6,"name":"Rectus abdominis"},{"id":7,"name":"Gastrocnemius"},{"id":8,"name":"Gluteus maximus"},{"id":9,"name":"Trapezius"},{"id":10,"name":"Quadriceps femoris"},{"id":11,"name":"Biceps femoris"},{"id":12,"name":"Latissimus dorsi"},{"id":13,"name":"Brachialis"},{"id":14,"name":"Obliquus externus abdominis"},{"id":15,"name":"Soleus"}],
      "equipment": [{"id":1,"name":"Barbell"},{"id":2,"name":"SZ-Bar"},{"id":3,"name":"Dumbbell"},{"id":4,"name":"Gym mat"},{"id":5,"name":"Swiss Ball"},{"id":6,"name":"Pull-up bar"},{"id":7,"name":"none (bodyweight exercise)"},{"id":8,"name":"Bench"},{"id":9,"name":"Incline bench"},{"id":10,"name":"Kettlebell"},{"id":11,"name":"Resistance band"},{"id":12,"name":"Cable machine"}],
      "licenses": [{"id":1,"name":"CC-BY-SA 3"},{"id":2,"name":"CC-BY-SA 4"},{"id":3,"name":"CC0"},{"id":4,"name":"CC-BY 4"},{"id":5,"name":"ODbL"}],
      "languages": [{"id":2,"short_name":"en"}],
      "exercises": [
        {
          "id":73,"uuid":"3717d144-7815-4a97-9a56-956fb889c996","category":{"id":11,"name":"Chest"},
          "muscles":[{"id":4,"name":"Pectoralis major"}],"muscles_secondary":[{"id":2,"name":"Anterior deltoid"},{"id":5,"name":"Triceps brachii"}],
          "equipment":[{"id":1,"name":"Barbell"},{"id":8,"name":"Bench"}],"license":{"id":1,"name":"CC-BY-SA 3"},
          "license_author":"sistab2","license_title":"","last_update_global":"2026-06-19T18:46:21.803261+02:00",
          "translations":[{"id":192,"uuid":"5da6340b-22ec-4c1b-a443-eef2f59f92f0","language":{"id":2},"name":"Bench Press","description_source":"Lay down on a bench, the bar should be directly above your eyes, the knees are somewhat angled and the feet are firmly on the floor. Concentrate, breath deeply and grab the bar more than shoulder wide. Bring it slowly down till it briefly touches your chest at the height of your nipples. Push the bar up.\n\nIf you train with a high weight it is advisable to have a *spotter* that can help you up if you can't lift the weight on your own.\n\nWith the width of the grip you can also control which part of the chest is trained more:\n\n* wide grip: outer chest muscles\n* narrow grip: inner chest muscles and triceps","aliases":[],"notes":[],"license":1,"license_title":"","license_author":"sistab2"}]
        },
        {
          "id":184,"uuid":"ee8e8db4-2d82-49e1-ab7f-891e9a354934","category":{"id":12,"name":"Back"},
          "muscles":[{"id":12,"name":"Latissimus dorsi"}],"muscles_secondary":[{"id":8,"name":"Gluteus maximus"}],
          "equipment":[{"id":1,"name":"Barbell"}],"license":{"id":1,"name":"CC-BY-SA 3"},
          "license_author":"wger.de","license_title":"","last_update_global":"2026-06-19T19:55:07.473226+02:00",
          "translations":[{"id":105,"uuid":"22cca8fc-cfaf-4941-b0f7-faf9f2937c52","language":{"id":2},"name":"Deadlifts","description_source":"Stand firmly, with your feet slightly more than shoulder wide apart. Stand directly behind the bar where it should barely touch your shin, your feet pointing a bit out. Bend down with a straight back, the knees also pointing somewhat out. Grab the bar with a shoulder wide grip, one overhand, one underhand (mixed grip).\n\nPull the weight up. At the highest point make a slight hollow back and pull the bar back. Hold 1 or 2 seconds that position. Go down, making sure the back is not bent. Once down you can either go back again as soon as the weights touch the floor, or make a pause, depending on the weight.","aliases":[],"notes":[],"license":1,"license_title":"","license_author":"wger.de"}]
        },
        {
          "id":615,"uuid":"a2f5b6ef-b780-49c0-8d96-fdaff23e27ce","category":{"id":9,"name":"Legs"},
          "muscles":[{"id":10,"name":"Quadriceps femoris"}],"muscles_secondary":[{"id":8,"name":"Gluteus maximus"}],
          "equipment":[{"id":1,"name":"Barbell"}],"license":{"id":1,"name":"CC-BY-SA 3"},
          "license_author":"wger.de","license_title":"","last_update_global":"2026-04-15T22:23:56.765145+02:00",
          "translations":[{"id":111,"uuid":"c4856da3-8454-4857-8997-336d06df590f","language":{"id":2},"name":"Squats","description_source":"Place a barbell in a rack just below shoulder-height. Dip under the bar to put it behind the neck across the top of the back, and grip the bar with the hands wider than shoulder-width apart. Lift the chest up and squeeze the shoulder blades together to keep the straight back throughout the entire movement. Stand up to bring the bar off the rack and step backwards, then place the feet so that they are a little wider than shoulder-width apart. Sit back into hips and keep the back straight and the chest up, squatting down so the hips are below the knees. From the bottom of the squat, press feet into the ground and push hips forward to return to the top of the standing position.","aliases":[],"notes":[],"license":1,"license_title":"","license_author":"wger.de"}]
        }
      ]
    }
    """#
}
