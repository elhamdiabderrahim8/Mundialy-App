import requests
import json

BASE_URL = "http://localhost:5000/api/worldcup/standings-2026"

def test_standings():
    print(f"📡 Test de l'endpoint Standings 2026: {BASE_URL}...")
    try:
        response = requests.get(BASE_URL, timeout=15)
        print(f"📥 Status Code: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            if 'response' in data and len(data['response']) > 0:
                print("✅ Succès: Données récupérées avec succès !")
                league = data['response'][0].get('league', {})
                standings = league.get('standings', [])
                print(f"🏆 Compétition: {league.get('name')} {league.get('season')}")
                print(f"📊 Nombre de groupes trouvés: {len(standings)}")

                if standings:
                    first_group = standings[0]
                    print(f"📍 Exemple - Premier Groupe: {first_group[0].get('group')}")
                    for team in first_group[:2]:
                        print(f"   - {team['team']['name']} (Rank: {team['rank']}, Pts: {team['points']})")
            else:
                print("⚠️ Attention: L'API a répondu mais la liste 'response' est vide.")
                print("Note: Cela peut arriver si la saison 2026 n'est pas encore ouverte dans API-SPORTS.")
        else:
            print(f"❌ Erreur: Le serveur a renvoyé une erreur {response.status_code}")
            print(f"Détails: {response.text}")

    except requests.exceptions.ConnectionError:
        print("❌ Erreur: Impossible de se connecter au serveur. Vérifiez que 'python app.py' est lancé.")
    except Exception as e:
        print(f"💥 Erreur inattendue: {e}")

if __name__ == "__main__":
    test_standings()
