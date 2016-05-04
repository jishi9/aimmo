import logging
import threading
import time

import requests

LOGGER = logging.getLogger(__name__)


class Worker(object):
    def __init__(self, game_id, player_id, code):
        self.game_id = game_id
        self.player_id
        self.code = code
        print 'Starting server for player %s in game %s' % (player_id, game_id)

    def is_running(self):
        return True

    def get_url(self):
        pass

    def stop(self):
        print 'Stopping server for player %s in game %s' % (self.player_id, self.game_id)


class WorkerManager2(object):
    def __init__(self, game_id):
        self.game_id = game_id
        self.workers = dict()


    def create_worker(self, player_id, *args):
        if player_id in self.workers:
            raise ValueError('Worker already exists')

        self.workers[player_id] = Worker(self.game_id, player_id, *args)


    def create_or_update_worker(self, player_id, *args):
        if player_id in self.workers:
            self.remove_worker(player_id)

        self.create_worker(player_id, *args)


    def remove_worker(self, player_id):
        if player_id not in self.workers:
            raise ValueError('Worker does not exist')

        worker = self.workers[player_id]
        del self.workers[player_id]
        worker.stop()

    def ensure_workers(self, player_ids):
        player_ids_to_keep = frozenset(player_ids)

        workers_to_remove = self.workers.keys() - player_ids_to_keep
        for worker in workers_to_remove:
            self.remove_worker(worker.player_id)

        workers_to_create = player_ids_to_keep - self.workers.keys()
        for player_id in workers_to_create:
            self.create_worker(player_id)

        workers_to_restart = [ w for w in self.workers if not w.is_running() ]
        for worker in workers_to_restart:
            self.create_or_update_worker(worker.player_id, *worker.args)



class WorkerManager(threading.Thread):
    daemon = True

    def __init__(self, game_state, users_url):
        self.game_state = game_state
        self.users_url = users_url
        self.user_codes = {}
        self.instance_launcher = NotImplemented
        super(WorkerManager, self).__init__()

    def maintain_worker_pool(self, expected_workers):


    def run(self):
        while True:
            try:
                game_data = requests.get(self.users_url).json()
            except (requests.RequestException, ValueError) as err:
                LOGGER.error("Obtaining game data failed: %s", err)
            else:
                game = game_data['main']
                for user in game['users']:
                    if self.user_codes.get(user['id'], None) != user['code']:
                        # Remove avatar from the game, so it stops being called
                        # for turns
                        self.game_state.remove_avatar(user['id'])
                        # Get persistent state from worker
                        # TODO
                        # Kill worker
                        # TODO
                        # Spawn worker
                        # Comes from spawning
                        worker_url = 'http://localhost:%d' % (
                            5000 + int(user['id']))
                        # TODO
                        # Initialise worker
                        requests.post("%s/initialise/" % worker_url, json={
                            'code': user['code'],
                            'options': {},
                        })
                        # Add avatar back into game
                        self.game_state.add_avatar(
                            user_id=user['id'], worker_url="%s/turn/" % worker_url)
                        self.user_codes[user['id']] = user['code']

            time.sleep(10)
