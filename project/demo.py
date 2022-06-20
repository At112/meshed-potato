from flask import Flask, jsonify
from flask_restful import Resource, Api

# creating the flask app
app = Flask(__name__)

# creating an API object
api = Api(app)


# they are automatically mapped by flask_restful.
class Version(Resource):

    # corresponds to the GET request.
    # this function is called whenever there
    # is a GET request for this resource
    def get(self):
        current_version = {"version": "2.0.0"}
        return jsonify(current_version)


# another resource for testing 
class Home(Resource):

    def get(self):
        test_api = {"ID" : "0001",
                    "Username" : "Ateeq",
                    "Location" : "PK",
                    "secret" : "xxxxxxxxxxxxxxxxxxxxxxxxxxx"
                    }
        return jsonify(test_api)


# adding the defined API resources along with their corresponding urls
api.add_resource(Version, '/version')
api.add_resource(Home, '/')

# driver function
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
    app.run(debug=True)


