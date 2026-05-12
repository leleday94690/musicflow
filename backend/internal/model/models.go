package model

import "time"

type Song struct {
	ID             int64     `json:"id"`
	Title          string    `json:"title"`
	Artist         string    `json:"artist"`
	Album          string    `json:"album"`
	Duration       int       `json:"duration"`
	CoverURL       string    `json:"coverUrl"`
	AudioURL       string    `json:"audioUrl"`
	Source         string    `json:"source"`
	IsFavorite     bool      `json:"isFavorite"`
	Lyrics         string    `json:"lyrics"`
	LyricsOffsetMs int       `json:"lyricsOffsetMs"`
	PlayCount      int       `json:"playCount"`
	CreatedAt      time.Time `json:"createdAt"`
}

type SongPage struct {
	Items      []Song `json:"items"`
	NextCursor int64  `json:"nextCursor"`
	HasMore    bool   `json:"hasMore"`
	TotalCount int    `json:"totalCount"`
}

type Playlist struct {
	ID          int64     `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	CoverURL    string    `json:"coverUrl"`
	Owner       string    `json:"owner"`
	IsFavorite  bool      `json:"isFavorite"`
	SongCount   int       `json:"songCount"`
	TotalTime   int       `json:"totalTime"`
	UpdatedAt   time.Time `json:"updatedAt"`
	Songs       []Song    `json:"songs,omitempty"`
}

type UserProfile struct {
	ID             int64  `json:"id"`
	Name           string `json:"name"`
	Username       string `json:"username"`
	AvatarURL      string `json:"avatarUrl"`
	Vip            bool   `json:"vip"`
	IsAdmin        bool   `json:"isAdmin"`
	FavoriteCount  int    `json:"favoriteCount"`
	PlaylistCount  int    `json:"playlistCount"`
	RecentCount    int    `json:"recentCount"`
	StorageUsedMB  int    `json:"storageUsedMb"`
	StorageLimitMB int    `json:"storageLimitMb"`
	StorageMusicMB int    `json:"storageMusicMb"`
}

type AuthSession struct {
	Token string      `json:"token"`
	User  UserProfile `json:"user"`
}

type ProfileOverview struct {
	User      UserProfile       `json:"user"`
	Favorites []Song            `json:"favorites"`
	Recent    []PlayHistoryItem `json:"recent"`
	Downloads []DownloadTask    `json:"downloads"`
}

type PlayHistoryItem struct {
	ID       int64     `json:"id"`
	Song     Song      `json:"song"`
	PlayedAt time.Time `json:"playedAt"`
}

type DownloadTask struct {
	ID        int64     `json:"id"`
	Song      Song      `json:"song"`
	Quality   string    `json:"quality"`
	Progress  int       `json:"progress"`
	Status    string    `json:"status"`
	UpdatedAt time.Time `json:"updatedAt"`
}

type DownloadTaskPage struct {
	Items          []DownloadTask `json:"items"`
	NextOffset     int            `json:"nextOffset"`
	HasMore        bool           `json:"hasMore"`
	TotalCount     int            `json:"totalCount"`
	AllCount       int            `json:"allCount"`
	CompletedCount int            `json:"completedCount"`
	ActiveCount    int            `json:"activeCount"`
	FailedCount    int            `json:"failedCount"`
}
