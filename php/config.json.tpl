{
    "settings": {
        "http": {
            "max_body_size": 134217728,
            "send_timeout": {{SEND_TIMEOUT}},
            "idle_timeout": {{IDLE_TIMEOUT}}
        }
    },

    "listeners": {
        "*:8080": {
            "pass": "routes"
        }
    },

    "routes": [
        {
            "action": {
                "share": "/app/www$uri",
                "fallback": {
                    "pass": "applications/php/index"
                }
            }
        }
    ],

    "applications": {
        "php": {
            "type": "php",
            "targets": {
                "direct": {
                    "root": "/app/www/"
                },

                "index": {
                    "root": "/app/www/",
                    "script": "index.php"
                }
            },
            "processes": {
                "max": {{PROCESSES_COUNT}},
                "spare": {{PROCESSES_COUNT}},
                "idle_timeout": 30
            },
            "options": {
                "user": {
                    "memory_limit": "{{MEMORY_LIMIT}}"
                },
                "admin": {}
            }
        }
    },

    "access_log": "/var/log/access.log"
}
