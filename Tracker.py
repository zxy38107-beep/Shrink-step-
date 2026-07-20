import requests
import datetime
from flask import Flask, request

# ==========================================
# CONFIGURATION
# ==========================================
WEBHOOK_URL = "https://discord.com/api/webhooks/1508723797166002186/gW9QsWmFD-QQort2WaW9sJSAmQJbexiurG-OrhXUMAhvqAz1qJEAetxTdb5fGCR2KlLw"
GITHUB_ROLE_ID = "1518777635587756132"

WATCHED_FILES = [
    "7zxy hub.lua"
]

IGNORED_FILES = [
    "README.md",
    ".gitignore",
    "LICENSE",
    "docs/",
]
# ==========================================

app = Flask(__name__)

@app.route('/')
def home():
    return "Script Tracker Running"

@app.route('/github', methods=['POST'])
def github_webhook():
    try:
        payload = request.json
        
        if request.headers.get('X-GitHub-Event') != 'push':
            return "Not a push event", 200
        
        repo_name = payload['repository']['name']
        branch = payload['ref'].split('/')[-1]
        pusher = payload['pusher']['name']
        commits = payload['commits']
        
        if branch not in ['main', 'master']:
            return "Non-main branch", 200
        
        relevant_commits = []
        for commit in commits:
            changed_files = commit.get('modified', []) + commit.get('added', [])
            
            for file in changed_files:
                if any(pattern in file for pattern in WATCHED_FILES):
                    if not any(ignore in file for ignore in IGNORED_FILES):
                        relevant_commits.append(commit)
                        break
        
        if not relevant_commits:
            return "No watched files changed", 200
        
        send_discord_alert(repo_name, pusher, branch, relevant_commits, GITHUB_ROLE_ID)
        return "Alert sent", 200
        
    except Exception as e:
        print(f"Error: {e}")
        return f"Error: {e}", 500

def send_discord_alert(repo_name, pusher, branch, commits, role_id):
    changelog_lines = []
    for commit in commits[:3]:
        msg = commit['message'].strip().split('\n')[0]
        changelog_lines.append(f"• {msg}")
    
    if len(commits) > 3:
        changelog_lines.append(f"• ... and {len(commits) - 3} more changes")
    
    changelog_text = "\n".join(changelog_lines)
    role_mention = f"<@&{role_id}>" if role_id else ""
    
    data = {
        "username": "Script Updates",
        "content": role_mention,
        "embeds": [{
            "title": f"📝 {repo_name} Updated",
            "description": f"Pushed by **{pusher}** to `{branch}`",
            "color": 5763719,
            "fields": [
                {
                    "name": "Changelog",
                    "value": f"```{changelog_text}```",
                    "inline": False
                },
                {
                    "name": "Commits",
                    "value": f"`{len(commits)}`",
                    "inline": True
                }
            ],
            "footer": {
                "text": f"Script Monitor • {datetime.datetime.utcnow().strftime('%d/%m/%Y %H:%M UTC')}"
            }
        }]
    }
    
    requests.post(WEBHOOK_URL, json=data)
    print(f"✓ Alert sent for {repo_name}")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
